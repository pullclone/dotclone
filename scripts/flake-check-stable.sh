#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# WSL and some constrained envs may not provide a writable /run/user/$UID.
if [ -z "${XDG_RUNTIME_DIR:-}" ] || [ ! -w "${XDG_RUNTIME_DIR:-}" ]; then
  export XDG_RUNTIME_DIR="/tmp/xdg-runtime-${UID}"
  install -d -m 0700 "$XDG_RUNTIME_DIR"
fi

if [ "$#" -gt 0 ]; then
  FLAKE_PATH="$1"
  shift
else
  FLAKE_PATH="."
fi

MAX_JOBS="${NIX_FLAKE_CHECK_MAX_JOBS:-1}"
CORES="${NIX_FLAKE_CHECK_CORES:-1}"
KEEP_OUTPUTS="${NIX_FLAKE_CHECK_KEEP_OUTPUTS:-false}"
KEEP_DERIVATIONS="${NIX_FLAKE_CHECK_KEEP_DERIVATIONS:-false}"
FALLBACK="${NIX_FLAKE_CHECK_FALLBACK:-true}"
CONNECT_TIMEOUT="${NIX_FLAKE_CHECK_CONNECT_TIMEOUT:-15}"
PRINT_BUILD_LOGS="${NIX_FLAKE_CHECK_PRINT_BUILD_LOGS:-true}"
ACCEPT_FLAKE_CONFIG="${NIX_FLAKE_CHECK_ACCEPT_FLAKE_CONFIG:-true}"
LOG_DIR="${NIX_FLAKE_CHECK_LOG_DIR:-/tmp}"

mkdir -p "$LOG_DIR"
if [ -n "${NIX_FLAKE_CHECK_LOG_FILE:-}" ]; then
  LOG_FILE="$NIX_FLAKE_CHECK_LOG_FILE"
else
  LOG_FILE="${LOG_DIR%/}/flake-check-stable-$(date +%Y%m%d-%H%M%S).log"
fi

cmd=(
  nix flake check "$FLAKE_PATH"
  --option max-jobs "$MAX_JOBS"
  --option cores "$CORES"
  --option keep-outputs "$KEEP_OUTPUTS"
  --option keep-derivations "$KEEP_DERIVATIONS"
  --option fallback "$FALLBACK"
  --option connect-timeout "$CONNECT_TIMEOUT"
)

if [ "$PRINT_BUILD_LOGS" = "true" ]; then
  cmd+=(--print-build-logs)
fi
if [ "$ACCEPT_FLAKE_CONFIG" = "true" ]; then
  cmd+=(--accept-flake-config)
fi
if [ "$#" -gt 0 ]; then
  cmd+=("$@")
fi

echo "==> Stable flake check profile"
echo "  flake_path=${FLAKE_PATH}"
echo "  max_jobs=${MAX_JOBS}"
echo "  cores=${CORES}"
echo "  keep_outputs=${KEEP_OUTPUTS}"
echo "  keep_derivations=${KEEP_DERIVATIONS}"
echo "  fallback=${FALLBACK}"
echo "  connect_timeout=${CONNECT_TIMEOUT}"
echo "  log_file=${LOG_FILE}"

set +e
"${cmd[@]}" >"$LOG_FILE" 2>&1
status=$?
set -e

echo "==> Exit status: ${status}"
echo "==> Log: ${LOG_FILE}"

if [ "$status" -eq 0 ]; then
  echo "Stable flake check passed."
  exit 0
fi

describe_cause() {
  local log="$1"
  local matcher="rg"

  if ! command -v rg >/dev/null 2>&1; then
    matcher="grep"
  fi

  matches() {
    local pattern="$1"
    if [ "$matcher" = "rg" ]; then
      rg -qi "$pattern" "$log"
    else
      grep -Eqi "$pattern" "$log"
    fi
  }

  if matches "cannot connect to socket at '/nix/var/nix/daemon-socket/socket': Operation not permitted|permission denied.*daemon-socket|nix-daemon.*not running"; then
    cat <<'EOF'
Likely cause: daemon socket access / permission issue.
Observed effective fix: run outside restrictive sandbox and ensure nix-daemon is reachable.
EOF
    return
  fi

  if matches "No space left on device|disk.*full|write error.*No space|failed to create (file|directory).*/nix/store"; then
    cat <<'EOF'
Likely cause: store or disk pressure during build/check.
Observed effective fixes:
- keep-outputs=false and keep-derivations=false to reduce retained paths.
- run nix GC before retry if the store is near capacity.
EOF
    return
  fi

  if matches "out of memory|Cannot allocate memory|oom-killer|killed process|SIGKILL|builder for .* failed with exit code 137"; then
    cat <<'EOF'
Likely cause: memory pressure during evaluation/build.
Observed effective fixes:
- max-jobs=1 and cores=1 to serialize work and lower peak memory.
- avoid parallel test/build steps while flake checks are running.
EOF
    return
  fi

  if matches "unable to download|could not resolve host|timed out|TLS|SSL|Connection reset|Failed to connect"; then
    cat <<'EOF'
Likely cause: network/substituter instability.
Observed effective fixes:
- fallback=true with conservative connect-timeout.
- retry serialized; if needed, pin substituters to cache.nixos.org.
EOF
    return
  fi

  cat <<'EOF'
Likely cause: unknown from heuristics.
Observed effective baseline fixes:
- max-jobs=1
- cores=1
- keep-outputs=false
- keep-derivations=false
Review the last 80 log lines below.
EOF
}

echo
echo "==> Failure triage"
describe_cause "$LOG_FILE"
echo
echo "==> Log tail"
tail -n 80 "$LOG_FILE"

exit "$status"
