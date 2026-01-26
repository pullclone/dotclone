#!/usr/bin/env bash
set -euo pipefail

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

default_log_root="${LOG_ROOT_DEFAULT:-/usb/ultrapeach/logs}"

ts="$(date -u +%Y%m%dT%H%MZ)"

FLAKE="${FLAKE:-/mnt/etc/nixos}"
HOST="${HOST:-nyx}"
INSTALLER="${INSTALLER:-/mnt/etc/dotclone/install-nyxos.sh}"
default_build_dir="${BUILD_DIR_DEFAULT:-}"
if [ -z "$default_build_dir" ]; then
  if [ -d /mnt/nix ]; then
    default_build_dir="/mnt/nix/build-tmp"
  elif [ -d /mnt ]; then
    default_build_dir="/tmp/build-tmp"
  else
    default_build_dir="/tmp/build-tmp"
  fi
fi

ensure_nix_daemon() {
  if ! command -v journalctl >/dev/null 2>&1; then
    echo "nix-daemon logging isn't available (journalctl not found)." >&2
    return 1
  fi
  if command -v systemctl >/dev/null 2>&1; then
    if ! $SUDO systemctl is-active --quiet nix-daemon; then
      echo "nix-daemon isn't running; starting it now..."
      if ! $SUDO systemctl start nix-daemon; then
        echo "Failed to start nix-daemon." >&2
        return 1
      fi
    fi
    if ! $SUDO systemctl is-active --quiet nix-daemon; then
      echo "nix-daemon is still not running." >&2
      return 1
    fi
    return 0
  fi
  if command -v pgrep >/dev/null 2>&1; then
    if pgrep -x nix-daemon >/dev/null 2>&1; then
      return 0
    fi
  fi
  echo "Unable to verify nix-daemon status." >&2
  return 1
}

prompt_log_root() {
  local entry create_choice
  while true; do
    read -r -p "Log directory [${default_log_root}]: " entry
    entry="${entry:-$default_log_root}"
    if [ -z "$entry" ]; then
      echo "That entry didn't match what we expected. Please enter a path." >&2
      continue
    fi
    if [ "${entry#/}" = "$entry" ]; then
      entry="$(pwd)/$entry"
    fi
    if [ -d "$entry" ]; then
      LOG_ROOT="$entry"
      return 0
    fi
    echo "Directory does not exist: $entry"
    read -r -p "Create it? [y/N]: " create_choice
    case "${create_choice:-N}" in
      y|Y)
        if $SUDO install -d -m 0755 "$entry"; then
          LOG_ROOT="$entry"
          return 0
        fi
        echo "That entry didn't match what we expected. Unable to create $entry." >&2
        ;;
      *)
        echo "That entry didn't match what we expected. Please choose another location." >&2
        ;;
    esac
  done
}

prompt_build_dir() {
  local entry create_choice
  while true; do
    read -r -p "Build temp directory [${default_build_dir}]: " entry
    entry="${entry:-$default_build_dir}"
    if [ -z "$entry" ]; then
      echo "That entry didn't match what we expected. Please enter a path." >&2
      continue
    fi
    if [ "${entry#/}" = "$entry" ]; then
      entry="$(pwd)/$entry"
    fi
    if [ -d "$entry" ]; then
      BUILD_DIR="$entry"
      return 0
    fi
    echo "Directory does not exist: $entry"
    read -r -p "Create it? [y/N]: " create_choice
    case "${create_choice:-N}" in
      y|Y)
        if $SUDO install -d -m 1777 "$entry"; then
          BUILD_DIR="$entry"
          return 0
        fi
        echo "That entry didn't match what we expected. Unable to create $entry." >&2
        ;;
      *)
        echo "That entry didn't match what we expected. Please choose another location." >&2
        ;;
    esac
  done
}

prompt_log_root
prompt_build_dir

if [ -n "${BUILD_DIR:-}" ]; then
  export NIX_CONFIG="build-dir = ${BUILD_DIR}"
fi

while true; do
  echo "Select workflow:"
  echo "  1) Nix toplevel build"
  echo "  2) install-nyxos.sh flow"
  read -r -p "> " workflow
  case "$workflow" in
    2) workflow="installer"; break ;;
    ""|1) workflow="toplevel"; break ;;
    *) echo "That entry didn't match what we expected. Choose 1 or 2." >&2 ;;
  esac
done

log_prefix="nix-build"
if [ "$workflow" = "installer" ]; then
  log_prefix="nyxos-install"
fi

build_log="/tmp/${log_prefix}-${ts}.log"
daemon_log="/tmp/nix-daemon-${ts}.log"

if [ "$workflow" = "toplevel" ]; then
  cat <<INFO
Build target: ${FLAKE}#nixosConfigurations.${HOST}.config.system.build.toplevel
Log dir: ${LOG_ROOT}
Build temp dir: ${BUILD_DIR}
INFO
else
  cat <<INFO
Installer: ${INSTALLER}
Log dir: ${LOG_ROOT}
Build temp dir: ${BUILD_DIR}
INFO
fi

echo "Select mode:"
if [ "$workflow" = "toplevel" ]; then
  echo "  1) Build only"
  echo "  2) Build + capture nix-daemon logs during build"
else
  echo "  1) Install flow only"
  echo "  2) Install flow + capture nix-daemon logs during run"
fi
capture_daemon="false"
while true; do
  read -r -p "> " mode
  case "$mode" in
    2)
      if ensure_nix_daemon; then
        capture_daemon="true"
        break
      fi
      echo "nix-daemon logging isn't available. Start nix-daemon or choose another mode." >&2
      ;;
    ""|1)
      capture_daemon="false"
      break
      ;;
    *)
      echo "That entry didn't match what we expected. Choose 1 or 2." >&2
      ;;
  esac
done

daemon_pid=""
if [ "$capture_daemon" = "true" ]; then
  $SUDO journalctl -u nix-daemon -b -f --no-pager > "$daemon_log" &
  daemon_pid=$!
  echo "nix-daemon log capture started (PID $daemon_pid)."
  echo "For live viewing in another terminal:"
  echo "  sudo journalctl -u nix-daemon -b -f --no-pager"
fi

set +e
if [ "$workflow" = "toplevel" ]; then
  nix --extra-experimental-features "nix-command flakes" \
    build "${FLAKE}#nixosConfigurations.${HOST}.config.system.build.toplevel" \
    -L --show-trace \
    --option build-dir "$BUILD_DIR" 2>&1 | tee "$build_log"
  build_status=${PIPESTATUS[0]}
else
  installer_cmd="$INSTALLER"
  if [ -n "$SUDO" ]; then
    installer_cmd="$SUDO --preserve-env=NIX_CONFIG $INSTALLER"
  fi
  if command -v script >/dev/null 2>&1; then
    script -q -e -c "$installer_cmd" "$build_log"
    build_status=$?
  else
    echo "Warning: 'script' not found; falling back to tee. Installer prompts may be degraded." >&2
    bash -c "$installer_cmd" 2>&1 | tee "$build_log"
    build_status=${PIPESTATUS[0]}
  fi
fi
set -e

if [ -n "$daemon_pid" ]; then
  $SUDO kill "$daemon_pid" >/dev/null 2>&1 || true
  wait "$daemon_pid" >/dev/null 2>&1 || true
fi

$SUDO install -m 0644 "$build_log" "$LOG_ROOT/"
if [ "$capture_daemon" = "true" ]; then
  $SUDO install -m 0644 "$daemon_log" "$LOG_ROOT/"
fi

echo "Logs saved to $LOG_ROOT"
exit "$build_status"
