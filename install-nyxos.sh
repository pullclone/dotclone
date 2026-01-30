#!/usr/bin/env bash
# shellcheck disable=SC2034
set -euo pipefail

echo "🌟 NyxOS Installer (Repo-Based)"
echo "================================="

###############################################################################
# Helpers
###############################################################################

ask() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  read -r -p "$prompt [$default]: " val
  # shellcheck disable=SC2163
  eval "$var_name='${val:-$default}'"
}

ask_yes_no() {
  local prompt="$1"
  local default="$2"  # y or n
  local var_name="$3"
  local val
  while true; do
    read -r -p "$prompt [${default}]: " val
    val="${val:-$default}"
    case "$val" in
      y|Y) eval "$var_name='true'"; return 0 ;;
      n|N) eval "$var_name='false'"; return 0 ;;
      *) echo "That entry isn't valid. Please answer y or n." >&2 ;;
    esac
  done
}

require_int() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
    echo "That entry isn't valid. $name must be an integer (got: $value)." >&2
    return 1
  fi
  return 0
}

normalize_timezone() {
  local tz="$1"
  local sign hour minute flipped offset_key
  TIMEZONE_NOTE=""
  if [[ "$tz" =~ ^UTC([+-])([0-9]{1,2})(:([0-9]{2}))?$ ]]; then
    sign="${BASH_REMATCH[1]}"
    hour="${BASH_REMATCH[2]}"
    minute="${BASH_REMATCH[4]:-00}"
    if [[ "$minute" == "30" ]]; then
      hour=$((10#$hour))
      offset_key="${sign}${hour}"
      case "$offset_key" in
        +3)
          TIMEZONE_NOTE="Note: UTC+03:30 maps to Asia/Tehran (DST may apply)."
          echo "Asia/Tehran"
          return 0
          ;;
        +4)
          TIMEZONE_NOTE="Note: UTC+04:30 maps to Asia/Kabul."
          echo "Asia/Kabul"
          return 0
          ;;
        +5)
          TIMEZONE_NOTE="Note: UTC+05:30 maps to Asia/Kolkata."
          echo "Asia/Kolkata"
          return 0
          ;;
        +6)
          TIMEZONE_NOTE="Note: UTC+06:30 maps to Asia/Yangon."
          echo "Asia/Yangon"
          return 0
          ;;
        +9)
          TIMEZONE_NOTE="Note: UTC+09:30 maps to Australia/Darwin."
          echo "Australia/Darwin"
          return 0
          ;;
        +10)
          TIMEZONE_NOTE="Note: UTC+10:30 maps to Australia/Lord_Howe (DST may apply)."
          echo "Australia/Lord_Howe"
          return 0
          ;;
        -3)
          TIMEZONE_NOTE="Note: UTC-03:30 maps to America/St_Johns (DST may apply)."
          echo "America/St_Johns"
          return 0
          ;;
        -9)
          TIMEZONE_NOTE="Note: UTC-09:30 maps to Pacific/Marquesas."
          echo "Pacific/Marquesas"
          return 0
          ;;
        *)
          return 1
          ;;
      esac
    fi
    if [[ "$minute" != "00" ]]; then
      return 1
    fi
    if (( 10#$hour == 0 )); then
      echo "UTC"
      return 0
    fi
    if [[ "$sign" == "+" ]]; then
      flipped="-"
    else
      flipped="+"
    fi
    hour=$((10#$hour))
    echo "Etc/GMT${flipped}${hour}"
    return 0
  fi
  echo "$tz"
}

zoneinfo_root() {
  if [[ -d /usr/share/zoneinfo ]]; then
    echo "/usr/share/zoneinfo"
    return 0
  fi
  if [[ -d /etc/zoneinfo ]]; then
    echo "/etc/zoneinfo"
    return 0
  fi
  return 1
}

print_columns() {
  if command -v column >/dev/null 2>&1; then
    column -x -c 120
  else
    pr -3 -t
  fi
}

setup_luks_container() {
  local root_part="$1"
  local mapper_name="$2"
  local allow_discards="$3"
  local open_args=()
  if [[ "$allow_discards" == "true" ]]; then
    open_args=(--allow-discards)
  fi

  while true; do
    if cryptsetup luksFormat --type luks2 "$root_part"; then
      break
    fi
    echo "That entry did not match what we expected. Please re-enter the passphrase." >&2
  done

  while true; do
    if cryptsetup open "${open_args[@]}" "$root_part" "$mapper_name"; then
      break
    fi
    echo "That entry did not match what we expected. Please re-enter the passphrase." >&2
  done
}

disable_swap_on_disk() {
  local disk="$1"
  local disk_real
  local swap_dev
  local swap_real
  disk_real="$(readlink -f "$disk" 2>/dev/null || echo "$disk")"
  if [[ ! -r /proc/swaps ]]; then
    return 0
  fi
  while read -r swap_dev _; do
    [[ "$swap_dev" == "Filename" ]] && continue
    swap_real="$(readlink -f "$swap_dev" 2>/dev/null || echo "$swap_dev")"
    if [[ "$swap_real" == "$disk_real"* ]]; then
      echo "Disabling swap on $swap_dev"
      swapoff "$swap_dev" || true
    fi
  done < /proc/swaps
}

ensure_build_dir() {
  local build_dir=""
  if [[ -n "${NIX_CONFIG:-}" ]]; then
    build_dir="$(
      printf '%s\n' "$NIX_CONFIG" | awk -F= '
        $1 ~ /^[[:space:]]*build-dir[[:space:]]*$/ {
          val=$2
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", val)
          print val
          exit
        }'
    )"
  fi
  if [[ -n "$build_dir" ]]; then
    mkdir -p "$build_dir"
  fi
}

list_timezones() {
  local root tmp list
  root="$(zoneinfo_root)" || {
    echo "❌ zoneinfo directory not found." >&2
    return 1
  }
  tmp="$(mktemp /tmp/nyxos-tzlist.XXXXXX)"
  {
    echo "IANA (Region/City)"
    echo "-------------------"
    list="$(
      find -L "$root" -type f \
        -not -path "$root/posix/*" \
        -not -path "$root/right/*" \
        -not -path "$root/SystemV/*" \
        -not -name "posixrules" \
        -not -name "localtime" \
        -not -name "leapseconds" \
        -not -name "zone.tab" \
        -not -name "zone1970.tab" \
        -not -name "tzdata.zi" \
        -not -name "iso3166.tab" \
        -printf '%P\n' | awk -F/ 'NF>1 && $1 != "Etc"'
    )"
    if [[ -n "$list" ]]; then
      printf '%s\n' "$list" | sort | print_columns
    else
      echo "(none)"
    fi
    echo ""
    echo "Abbreviations"
    echo "-------------"
    list="$(
      find -L "$root" -type f \
        -not -path "$root/posix/*" \
        -not -path "$root/right/*" \
        -not -path "$root/SystemV/*" \
        -not -name "posixrules" \
        -not -name "localtime" \
        -not -name "leapseconds" \
        -not -name "zone.tab" \
        -not -name "zone1970.tab" \
        -not -name "tzdata.zi" \
        -not -name "iso3166.tab" \
        -printf '%P\n' | awk -F/ 'NF==1'
    )"
    if [[ -n "$list" ]]; then
      printf '%s\n' "$list" | sort | print_columns
    else
      echo "(none)"
    fi
    echo ""
    echo "Etc/*"
    echo "-----"
    if [[ -d "$root/Etc" ]]; then
      list="$(find -L "$root/Etc" -type f -printf 'Etc/%f\n' 2>/dev/null || true)"
    else
      list=""
    fi
    if [[ -n "$list" ]]; then
      printf '%s\n' "$list" | sort | print_columns
    else
      echo "(none)"
    fi
    echo ""
    echo "UTC Offsets (UTC±HH:00, UTC±HH:30)"
    echo "---------------------------------"
    {
      for offset in $(seq -14 14); do
        if (( offset == 0 )); then
          echo "UTC+00:00"
        elif (( offset < 0 )); then
          printf 'UTC-%02d:00\n' "$((-offset))"
        else
          printf 'UTC+%02d:00\n' "$offset"
        fi
      done
      printf '%s\n' \
        "UTC-09:30" \
        "UTC-03:30" \
        "UTC+03:30" \
        "UTC+04:30" \
        "UTC+05:30" \
        "UTC+06:30" \
        "UTC+09:30" \
        "UTC+10:30"
    } | sort | print_columns
  } > "$tmp"

  if command -v less >/dev/null 2>&1; then
    less -F -X "$tmp"
  else
    cat "$tmp"
  fi
  rm -f "$tmp"
}

list_timezones_etc() {
  local root tmp list
  root="$(zoneinfo_root)" || {
    echo "❌ zoneinfo directory not found." >&2
    return 1
  }
  tmp="$(mktemp /tmp/nyxos-tzlist.XXXXXX)"
  {
    echo "Etc/*"
    echo "-----"
    list="$(
      find -L "$root/Etc" -type f -printf 'Etc/%f\n' 2>/dev/null || true
    )"
    if [[ -n "$list" ]]; then
      printf '%s\n' "$list" | sort | print_columns
    else
      echo "(none)"
    fi
  } > "$tmp"

  if command -v less >/dev/null 2>&1; then
    less -F -X "$tmp"
  else
    cat "$tmp"
  fi
  rm -f "$tmp"
}

compute_part_prefix() {
  case "$1" in
    *nvme*) echo "p" ;;
    *) echo "" ;;
  esac
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

detect_cpu_vendor() {
  if grep -qi "GenuineIntel" /proc/cpuinfo; then
    echo "intel"
    return 0
  fi
  if grep -qi "AuthenticAMD" /proc/cpuinfo; then
    echo "amd"
    return 0
  fi
  echo "unknown"
}

detect_gpu_from_lspci() {
  local line
  local primary="unknown"
  local has_nvidia="false"
  local has_amd="false"
  local has_intel="false"

  while IFS= read -r line; do
    if echo "$line" | grep -Eqi "\\[10de:"; then
      has_nvidia="true"
      [[ "$primary" == "unknown" ]] && primary="nvidia"
    elif echo "$line" | grep -Eqi "\\[1002:"; then
      has_amd="true"
      [[ "$primary" == "unknown" ]] && primary="amd"
    elif echo "$line" | grep -Eqi "\\[8086:"; then
      has_intel="true"
      [[ "$primary" == "unknown" ]] && primary="intel"
    fi
  done < <(lspci -nn | grep -Ei "(VGA|3D|Display)" || true)

  echo "${has_nvidia},${has_amd},${has_intel},${primary}"
}

detect_gpu_from_sysfs() {
  local dev class vendor
  local primary="unknown"
  local has_nvidia="false"
  local has_amd="false"
  local has_intel="false"

  for dev in /sys/bus/pci/devices/*; do
    class="$(cat "$dev/class" 2>/dev/null || true)"
    [[ "$class" =~ ^0x03 ]] || continue
    vendor="$(cat "$dev/vendor" 2>/dev/null || true)"
    case "$vendor" in
      0x10de)
        has_nvidia="true"
        [[ "$primary" == "unknown" ]] && primary="nvidia"
        ;;
      0x1002)
        has_amd="true"
        [[ "$primary" == "unknown" ]] && primary="amd"
        ;;
      0x8086)
        has_intel="true"
        [[ "$primary" == "unknown" ]] && primary="intel"
        ;;
    esac
  done

  echo "${has_nvidia},${has_amd},${has_intel},${primary}"
}

has_nvidia() {
  [[ "$GPU_HAS_NVIDIA" == "true" ]]
}

pci_to_xorg_busid() {
  # 0000:01:00.0 -> PCI:1:0:0
  local pci="$1"
  local bus dev func
  bus="$(echo "$pci" | cut -d: -f2)"
  dev="$(echo "$pci" | cut -d: -f3 | cut -d. -f1)"
  func="$(echo "$pci" | cut -d. -f2)"
  printf "PCI:%d:%d:%d" "0x$bus" "0x$dev" "0x$func"
}

first_pci_of_lspci() {
  # $1 = vendor regex (NVIDIA|Intel|AMD|ATI)
  lspci -D | grep -Ei "(VGA|3D|Display).*$1" | awk "NR==1{print \$1}"
}

first_pci_of_sysfs() {
  # $1 = vendor id (0x10de, 0x1002, 0x8086)
  local dev class vendor
  for dev in /sys/bus/pci/devices/*; do
    class="$(cat "$dev/class" 2>/dev/null || true)"
    [[ "$class" =~ ^0x03 ]] || continue
    vendor="$(cat "$dev/vendor" 2>/dev/null || true)"
    if [[ "$vendor" == "$1" ]]; then
      basename "$dev"
      return 0
    fi
  done
  return 1
}

detect_nvidia_busid() {
  local pci=""
  if has_command lspci; then
    pci="$(first_pci_of_lspci "NVIDIA" || true)"
  fi
  if [[ -z "$pci" ]]; then
    pci="$(first_pci_of_sysfs "0x10de" || true)"
  fi
  [[ -n "$pci" ]] || return 1
  pci_to_xorg_busid "$pci"
}

detect_igpu_busid() {
  local pci=""
  if has_command lspci; then
    pci="$(first_pci_of_lspci "Intel" || true)"
    if [[ -n "$pci" ]]; then
      echo "intel:$(pci_to_xorg_busid "$pci")"
      return 0
    fi
    pci="$(first_pci_of_lspci "AMD|ATI" || true)"
    if [[ -n "$pci" ]]; then
      echo "amd:$(pci_to_xorg_busid "$pci")"
      return 0
    fi
  fi

  pci="$(first_pci_of_sysfs "0x8086" || true)"
  if [[ -n "$pci" ]]; then
    echo "intel:$(pci_to_xorg_busid "$pci")"
    return 0
  fi
  pci="$(first_pci_of_sysfs "0x1002" || true)"
  if [[ -n "$pci" ]]; then
    echo "amd:$(pci_to_xorg_busid "$pci")"
    return 0
  fi
  return 1
}

RUN_MODE="install"
RUN_MODE_FORCED="false"
if [[ "${1:-}" == "--dry-run" ]]; then
  RUN_MODE="dry-run"
  RUN_MODE_FORCED="true"
  shift
elif [[ "${1:-}" == "--install" ]]; then
  RUN_MODE="install"
  RUN_MODE_FORCED="true"
  shift
fi
if [[ "$#" -gt 0 ]]; then
  echo "Usage: $0 [--dry-run|--install]" >&2
  exit 1
fi

if [[ "$RUN_MODE_FORCED" != "true" ]]; then
  ask_yes_no "Dry-run mode (build only; no disk changes)?" "n" DRY_RUN
  if [[ "$DRY_RUN" == "true" ]]; then
    RUN_MODE="dry-run"
  fi
fi

if [[ "$RUN_MODE" == "dry-run" ]]; then
  echo ""
  echo "Dry-run mode selected: disk operations, hardware config generation, and nixos-install will be skipped."
fi

ANSWERS_ROOT="/mnt/etc/nixos"
if [[ "$RUN_MODE" == "dry-run" ]]; then
  ANSWERS_ROOT="/etc/nixos"
  install -d -m 0755 "$ANSWERS_ROOT"
fi

###############################################################################
# 0) Disk selection
###############################################################################

if [[ "$RUN_MODE" != "dry-run" ]]; then
  echo ""
  echo "Available block devices:"
  lsblk -d -p -o NAME,SIZE,MODEL

  ask "Enter disk to install onto (e.g. /dev/sda or /dev/nvme0n1)" "/dev/sda" DISK
  PART_PREFIX="$(compute_part_prefix "$DISK")"

  echo ""
  echo "⚠️  This will destroy ALL data on: $DISK"
  while true; do
    read -r -p "Type YES to continue: " CONFIRM
    if [[ "$CONFIRM" == "YES" ]]; then
      break
    fi
    echo "That entry didn't match. Type YES to continue or press Ctrl-C to abort." >&2
  done
else
  DISK=""
  PART_PREFIX=""
fi

###############################################################################
# 1) Collect base answers
###############################################################################

while true; do
  ask "Enter Username" "ashy" USERNAME
  if [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    break
  fi
  echo "That entry isn't valid. Use lowercase letters, digits, '-' or '_' only." >&2
done

ask "Enter Hostname" "nyx" HOSTNAME

TIMEZONE_ROOT="$(zoneinfo_root || true)"
if [[ -z "$TIMEZONE_ROOT" ]]; then
  echo "❌ zoneinfo directory not found." >&2
  exit 1
fi
while true; do
  ask "Enter Timezone (e.g. MST, UTC-07:00, America/Denver; type 'list' or 'lsetc')" "UTC" TIMEZONE
  if [[ "${TIMEZONE,,}" == "list" ]]; then
    list_timezones || true
    continue
  fi
  if [[ "${TIMEZONE,,}" == "lsetc" ]]; then
    list_timezones_etc || true
    continue
  fi
  if ! TIMEZONE="$(normalize_timezone "$TIMEZONE")"; then
    echo "That entry isn't valid. Unsupported UTC offset format: $TIMEZONE" >&2
    continue
  fi
  if [[ ! -e "$TIMEZONE_ROOT/$TIMEZONE" ]]; then
    echo "That entry isn't valid. Timezone not found: $TIMEZONE" >&2
    continue
  fi
  if [[ -n "${TIMEZONE_NOTE:-}" ]]; then
    echo "$TIMEZONE_NOTE"
  fi
  break
done

###############################################################################
# 1a) Keyboard preset
###############################################################################

echo ""
echo "Select default keyboard layout:"
echo "  1) QWERTY"
echo "  2) Dvorak"
echo "  3) Colemak"
echo "  4) Workman"
echo "  5) Halmak"
echo "  6) Engram V2"
echo "  7) Bepo"
echo "  8) Neo"
echo "  9) EurKEY"
echo " 10) EurKEY Colemak-DH"
KEYBOARD_PRESET="qwerty"
while true; do
  ask "Choice" "1" KEYBOARD_CHOICE
  case "$KEYBOARD_CHOICE" in
    1) KEYBOARD_PRESET="qwerty"; break ;;
    2) KEYBOARD_PRESET="dvorak"; break ;;
    3) KEYBOARD_PRESET="colemak"; break ;;
    4) KEYBOARD_PRESET="workman"; break ;;
    5) KEYBOARD_PRESET="halmak"; break ;;
    6) KEYBOARD_PRESET="engram-v2"; break ;;
    7) KEYBOARD_PRESET="bepo"; break ;;
    8) KEYBOARD_PRESET="neo"; break ;;
    9) KEYBOARD_PRESET="eurkey"; break ;;
    10) KEYBOARD_PRESET="eurkey-colemak-dh"; break ;;
    *) echo "That entry isn't valid. Choose a number from 1 to 10." >&2 ;;
  esac
done
KEYBOARD_ENABLE="true"

###############################################################################
# 1b) Hardware auth + SSH identity (facts)
###############################################################################

echo ""
echo "Hardware auth capabilities (facts only):"
ask_yes_no "Trezor device available?" "n" HWAUTH_TREZOR_PRESENT
HWAUTH_TREZOR_MODEL="unknown"
if [[ "$HWAUTH_TREZOR_PRESENT" == "true" ]]; then
  while true; do
    ask "Trezor model (one|t|unknown)" "one" HWAUTH_TREZOR_MODEL
    case "$HWAUTH_TREZOR_MODEL" in
      one|t|unknown) break ;;
      *) echo "That entry isn't valid. Choose one, t, or unknown." >&2 ;;
    esac
  done
fi
ask_yes_no "FIDO2/CTAP2 device available?" "n" HWAUTH_FIDO2_PRESENT

echo ""
echo "SSH identity:"
echo "  1) file  (ed25519/rsa file-based keys)"
echo "  2) fido2 (ed25519-sk; requires FIDO2 device)"
SSH_IDENTITY="file"
while true; do
  ask "Choice" "1" SSH_IDENTITY_CHOICE
  case "$SSH_IDENTITY_CHOICE" in
    1) SSH_IDENTITY="file"; break ;;
    2) SSH_IDENTITY="fido2"; break ;;
    *) echo "That entry isn't valid. Choose 1 or 2." >&2 ;;
  esac
done
if [[ "$SSH_IDENTITY" == "fido2" && "$HWAUTH_FIDO2_PRESENT" != "true" ]]; then
  echo "WARNING: SSH identity set to fido2 but no FIDO2 device is marked present."
fi

###############################################################################
# 1c) SSH policy (declarative profiles)
###############################################################################

echo ""
echo "Declarative SSH profile policy:"
ask_yes_no "Enable declarative SSH profiles?" "y" SSH_POLICY_ENABLE

SSH_PROFILE="base"
SSH_FEATURES=()
SSH_FEATURES_NIX="[ ]"
SSH_KNOWNHOSTS_ENABLE="true"
SSH_ONEPASSWORD_ENABLE="false"

if [[ "$SSH_POLICY_ENABLE" == "true" ]]; then
  echo ""
  echo "Choose SSH client profile:"
  echo "  1) base      (strict baseline)"
  echo "  2) developer (multiplexing + convenience)"
  echo "  3) hardened  (strictest client posture)"
  echo "  4) home      (personal convenience)"
  echo "  5) ci        (automation / non-interactive)"
  while true; do
    ask "Choice" "1" SSH_PROFILE_CHOICE
    case "$SSH_PROFILE_CHOICE" in
      1) SSH_PROFILE="base"; break ;;
      2) SSH_PROFILE="developer"; break ;;
      3) SSH_PROFILE="hardened"; break ;;
      4) SSH_PROFILE="home"; break ;;
      5) SSH_PROFILE="ci"; break ;;
      *) echo "That entry isn't valid. Choose 1 to 5." >&2 ;;
    esac
  done

  echo ""
  echo "Optional SSH feature bundles (all default to no):"
  ask_yes_no "Enable git host presets?" "n" SSH_FEATURE_GIT
  ask_yes_no "Enable bastion/jump host patterns?" "n" SSH_FEATURE_BASTION
  ask_yes_no "Enable cloud host patterns?" "n" SSH_FEATURE_CLOUD
  ask_yes_no "Enable corporate/Kerberos patterns?" "n" SSH_FEATURE_CORP
  ask_yes_no "Enable legacy crypto exceptions?" "n" SSH_FEATURE_LEGACY
  ask_yes_no "Enable unreliable network tuning?" "n" SSH_FEATURE_UNRELIABLE

  if [[ "$SSH_FEATURE_GIT" == "true" ]]; then SSH_FEATURES+=( "git-hosts" ); fi
  if [[ "$SSH_FEATURE_BASTION" == "true" ]]; then SSH_FEATURES+=( "bastion" ); fi
  if [[ "$SSH_FEATURE_CLOUD" == "true" ]]; then SSH_FEATURES+=( "cloud" ); fi
  if [[ "$SSH_FEATURE_CORP" == "true" ]]; then SSH_FEATURES+=( "corporate" ); fi
  if [[ "$SSH_FEATURE_LEGACY" == "true" ]]; then SSH_FEATURES+=( "legacy" ); fi
  if [[ "$SSH_FEATURE_UNRELIABLE" == "true" ]]; then SSH_FEATURES+=( "unreliable" ); fi

  if ((${#SSH_FEATURES[@]})); then
    SSH_FEATURES_NIX="[ $(printf '\"%s\" ' "${SSH_FEATURES[@]}") ]"
  fi

  echo ""
  ask_yes_no "Enable system SSH known_hosts policy (pins/CA)?" "y" SSH_KNOWNHOSTS_ENABLE
  ask_yes_no "Use 1Password SSH agent (IdentityAgent ~/.1password/agent.sock)?" "n" SSH_ONEPASSWORD_ENABLE
else
  SSH_KNOWNHOSTS_ENABLE="false"
fi

###############################################################################
# 2) MAC policy
###############################################################################

echo ""
echo "Select MAC Address Policy:"
echo "  1) default (let NetworkManager decide)"
echo "  2) random  (randomize on every connection)"
echo "  3) stable  (stable per-network randomization)"
echo "  4) fixed   (spoof a specific address)"
MAC_MODE="default"
MAC_INTF=""
MAC_ADDR=""
while true; do
  ask "Choice" "1" MAC_CHOICE
  case "$MAC_CHOICE" in
    1)
      MAC_MODE="default"
      break
      ;;
    2)
      MAC_MODE="random"
      break
      ;;
    3)
      MAC_MODE="stable"
      break
      ;;
    4)
      MAC_MODE="fixed"
      while true; do
        ask "Interface (e.g. enp1s0)" "enp1s0" MAC_INTF
        if [[ -z "$MAC_INTF" ]]; then
          echo "That entry isn't valid. Interface cannot be empty." >&2
          continue
        fi
        ask "Address (e.g. 00:11:22:33:44:55)" "" MAC_ADDR
        if [[ "$MAC_ADDR" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
          break
        fi
        echo "That entry isn't valid. Please enter a MAC like 00:11:22:33:44:55." >&2
      done
      break
      ;;
    *) echo "That entry isn't valid. Choose 1, 2, 3, or 4." >&2 ;;
  esac
done

###############################################################################
# 3) Boot mode + trust phase
###############################################################################

echo ""
echo "Select Boot Mode:"
echo "  1) Secure Boot (recommended) — Lanzaboote (requires firmware SB enforcing)"
echo "  2) UKI baseline (dev-friendly) — systemd-boot/UKI"
BOOT_MODE="uki"
while true; do
  ask "Choice" "2" BOOT_CHOICE
  case "$BOOT_CHOICE" in
    1) BOOT_MODE="secureboot"; break ;;
    2) BOOT_MODE="uki"; break ;;
    *) echo "That entry isn't valid. Choose 1 or 2." >&2 ;;
  esac
done

echo ""
echo "Select Trust Phase:"
echo "  1) dev      (TPM deferred, no SB enforcement assertions)"
echo "  2) enforced (SB/TPM assertions enabled; TPM enrollment still manual)"
TRUST_PHASE="dev"
while true; do
  ask "Choice" "1" TRUST_CHOICE
  case "$TRUST_CHOICE" in
    1) TRUST_PHASE="dev"; break ;;
    2) TRUST_PHASE="enforced"; break ;;
    *) echo "That entry isn't valid. Choose 1 or 2." >&2 ;;
  esac
done

###############################################################################
# 4) Snapshots (btrbk retention)
###############################################################################

echo ""
echo "Btrfs snapshot retention (btrbk):"
echo "  Recommended: 7–15"
echo "  Default: 11"
echo "  -1 = not configured (NyxOS will not manage snapshots)"
echo "   0 = disable snapshots explicitly"
while true; do
  ask "Retention count" "11" SNAP_RETENTION
  if ! require_int "Snapshot retention" "$SNAP_RETENTION"; then
    continue
  fi

  if (( SNAP_RETENTION > 33 )); then
    echo ""
    echo "⚠️  You entered $SNAP_RETENTION snapshots."
    echo "    This is more than a reasonable default and may consume significant space."
    ask_yes_no "Continue with $SNAP_RETENTION snapshots?" "n" SNAP_RETENTION_OK
    if [[ "$SNAP_RETENTION_OK" != "true" ]]; then
      echo "Let's try again."
      continue
    fi
  fi
  break
done

ask_yes_no "Enable pre/post nixos-rebuild snapshots?" "y" SNAP_PREPOST
# schedule is kept simple here; you can expand later.
SNAP_SCHEDULE="daily"

###############################################################################
# 5) Storage trim policy (fstrim + LUKS discards intent)
###############################################################################

echo ""
echo "TRIM policy:"
echo "  Recommended: weekly fstrim, no continuous discard mount option"
ask_yes_no "Enable weekly fstrim timer?" "y" TRIM_ENABLE
TRIM_INTERVAL="weekly"

# Allow/disallow discards for LUKS (if enabled).
ask_yes_no "Allow discards through LUKS layer (if luks2 is selected)?" "y" LUKS_ALLOW_DISCARDS

###############################################################################
# 6) Encryption
###############################################################################

echo ""
echo "Encryption:"
echo "  1) none  (unencrypted Btrfs root)"
echo "  2) luks2 (LUKS2 container with Btrfs inside)"
ENC_MODE="none"
while true; do
  ask "Choice" "1" ENC_CHOICE
  case "$ENC_CHOICE" in
    1) ENC_MODE="none"; break ;;
    2) ENC_MODE="luks2"; break ;;
    *) echo "That entry isn't valid. Choose 1 or 2." >&2 ;;
  esac
done
if [[ "$ENC_MODE" == "luks2" ]]; then
  echo ""
  echo "LUKS2 selected. You will be prompted for a passphrase during formatting."
fi

###############################################################################
# 6b) GPG-decrypted LUKS keyfile (Trezor One)
###############################################################################

echo ""
echo "GPG-decrypted LUKS keyfile (Trezor One):"
LUKS_GPG_ENABLE="false"
if [[ "$ENC_MODE" == "luks2" ]]; then
  ask_yes_no "Enable GPG keyfile unlock (initrd, adds to passphrase)?" "n" LUKS_GPG_ENABLE
else
  echo "Note: GPG keyfile unlock requires LUKS2; skipping."
fi
LUKS_GPG_DEVICE=""
LUKS_GPG_MAPPER="root"
LUKS_GPG_KEYFILE="/persist/keys/root.key.gpg"
LUKS_GPG_KEY_DEVICE="/dev/disk/by-label/persist"
LUKS_GPG_KEY_FSTYPE="ext4"
KEYFILE_LOCATION="on-device"
if [[ "$LUKS_GPG_ENABLE" == "true" ]]; then
  echo "Note: Passphrase remains enabled; the keyfile adds an additional unlock method."
  if [[ "$HWAUTH_TREZOR_PRESENT" != "true" ]]; then
    echo "WARNING: GPG keyfile unlock enabled but no Trezor is marked present."
  fi
  echo ""
  echo "Keyfile storage location:"
  echo "  1) on-device persist partition (default, convenience)"
  echo "  2) external device (USB; stronger 2-of-2)"
  while true; do
    ask "Choice" "1" KEYFILE_LOCATION_CHOICE
    case "$KEYFILE_LOCATION_CHOICE" in
      1|"") KEYFILE_LOCATION="on-device"; break ;;
      2) KEYFILE_LOCATION="external"; break ;;
      *) echo "That entry isn't valid. Choose 1 or 2." >&2 ;;
    esac
  done
  ask "LUKS device path" "/dev/disk/by-label/nixos" LUKS_GPG_DEVICE
  ask "LUKS mapper name" "root" LUKS_GPG_MAPPER
  ask "Encrypted keyfile path (persist mount)" "/persist/keys/root.key.gpg" LUKS_GPG_KEYFILE
  if [[ "$KEYFILE_LOCATION" == "external" ]]; then
    echo "External device will be mounted at /persist in initrd."
  fi
  ask "Encrypted keyfile device (persist/external)" "/dev/disk/by-label/persist" LUKS_GPG_KEY_DEVICE
  while true; do
    ask "Encrypted keyfile filesystem type (ext4|btrfs)" "ext4" LUKS_GPG_KEY_FSTYPE
    case "$LUKS_GPG_KEY_FSTYPE" in
      ext4|btrfs) break ;;
      *) echo "That entry isn't valid. Choose ext4 or btrfs." >&2 ;;
    esac
  done
fi

LUKS_MAPPER_NAME="${LUKS_GPG_MAPPER}"
if [[ -z "$LUKS_MAPPER_NAME" ]]; then
  LUKS_MAPPER_NAME="root"
fi

PERSIST_ENABLE="false"
PERSIST_SIZE_MIB="64"
PERSIST_FSTYPE="ext4"
PERSIST_LABEL="persist"
if [[ "$LUKS_GPG_ENABLE" == "true" ]]; then
  echo ""
  if [[ "$KEYFILE_LOCATION" == "on-device" ]]; then
    echo "Encrypted keyfile storage: on-device persist partition."
    PERSIST_ENABLE="true"
    while true; do
      ask "Persist size in MiB" "$PERSIST_SIZE_MIB" PERSIST_SIZE_MIB
      if ! require_int "Persist size MiB" "$PERSIST_SIZE_MIB"; then
        continue
      fi
      if (( PERSIST_SIZE_MIB < 64 )); then
        echo "That entry isn't valid. Persist size must be >= 64 MiB." >&2
        continue
      fi
      break
    done
    while true; do
      ask "Persist filesystem type (ext4|btrfs)" "$PERSIST_FSTYPE" PERSIST_FSTYPE
      case "$PERSIST_FSTYPE" in
        ext4|btrfs) break ;;
        *) echo "That entry isn't valid. Choose ext4 or btrfs." >&2 ;;
      esac
    done
    LUKS_GPG_KEY_FSTYPE="$PERSIST_FSTYPE"
  else
    echo "Encrypted keyfile storage: external device."
    echo "Note: You must provide and mount the external device at /persist."
  fi
fi

###############################################################################
# 7) Swap policy
###############################################################################

echo ""
echo "Swap configuration:"
echo "  1) partition (recommended for now; installer creates it)"
echo "  2) none      (installer will skip creating swap)"
SWAP_MODE="partition"
while true; do
  ask "Choice" "1" SWAP_CHOICE
  case "$SWAP_CHOICE" in
    1) SWAP_MODE="partition"; break ;;
    2) SWAP_MODE="none"; break ;;
    *) echo "That entry isn't valid. Choose 1 or 2." >&2 ;;
  esac
done

SWAP_SIZE_GIB="8"
if [[ "$SWAP_MODE" == "partition" ]]; then
  while true; do
    ask "Swap size in GiB" "8" SWAP_SIZE_GIB
    if ! require_int "Swap size GiB" "$SWAP_SIZE_GIB"; then
      continue
    fi
    if (( SWAP_SIZE_GIB < 0 )); then
      echo "That entry isn't valid. Swap size must be >= 0." >&2
      continue
    fi
    break
  done
fi

###############################################################################
# 8) System tuning profile (optional)
###############################################################################

echo ""
echo "System profile (tuning defaults):"
echo "  1) balanced (default)"
echo "  2) latency"
echo "  3) throughput"
echo "  4) battery"
echo "  5) memory-saver"
SYSTEM_PROFILE="balanced"
while true; do
  ask "Choice" "1" PROFILE_CHOICE
  case "$PROFILE_CHOICE" in
    1) SYSTEM_PROFILE="balanced"; break ;;
    2) SYSTEM_PROFILE="latency"; break ;;
    3) SYSTEM_PROFILE="throughput"; break ;;
    4) SYSTEM_PROFILE="battery"; break ;;
    5) SYSTEM_PROFILE="memory-saver"; break ;;
    *) echo "That entry isn't valid. Choose a number from 1 to 5." >&2 ;;
  esac
done

###############################################################################
# 8b) Build target (flake output)
###############################################################################

echo ""
echo "Build target (nixosConfigurations.<target>):"
while true; do
  ask "Target" "nyx" BUILD_TARGET
  if [[ -z "$BUILD_TARGET" ]]; then
    echo "That entry isn't valid. Build target cannot be empty." >&2
    continue
  fi
  if ! [[ "$BUILD_TARGET" =~ ^[A-Za-z0-9._-]+$ ]]; then
    echo "That entry isn't valid. Use letters, digits, dot, dash, or underscore only." >&2
    continue
  fi
  break
done

###############################################################################
# 8c) Gaming options (optional)
###############################################################################

echo ""
echo "Gaming options (optional):"
ask_yes_no "Enable Steam?" "n" GAME_STEAM
ask_yes_no "Enable GameMode?" "n" GAME_GAMEMODE
ask_yes_no "Enable Gamescope?" "n" GAME_GAMESCOPE
ask_yes_no "Enable Lutris?" "n" GAME_LUTRIS
ask_yes_no "Enable RSI launcher (nix-citizen)?" "n" GAME_RSI
ask_yes_no "Enable Wine (wineWowPackages.stable + waylandFull + winetricks)?" "n" GAME_WINE
ask_yes_no "Enable EmulationStation (classic)?" "n" GAME_EMULATIONSTATION
if [[ "$GAME_RSI" == "true" && "$GAME_LUTRIS" != "true" ]]; then
  echo "Note: RSI launcher expects Lutris; enabling Lutris."
  GAME_LUTRIS="true"
fi

###############################################################################
# 9) Hardware detection + NVIDIA support (optional)
###############################################################################

echo ""
CPU_VENDOR="$(detect_cpu_vendor)"

GPU_HAS_NVIDIA="false"
GPU_HAS_AMD="false"
GPU_HAS_INTEL="false"
GPU_PRIMARY="unknown"

if has_command lspci; then
  IFS="," read -r GPU_HAS_NVIDIA GPU_HAS_AMD GPU_HAS_INTEL GPU_PRIMARY < <(detect_gpu_from_lspci)
fi

if [[ "$GPU_PRIMARY" == "unknown" ]]; then
  IFS="," read -r GPU_HAS_NVIDIA GPU_HAS_AMD GPU_HAS_INTEL GPU_PRIMARY < <(detect_gpu_from_sysfs)
fi

NVIDIA_MODE="desktop"
NVIDIA_OPEN="true"
NVIDIA_NVIDIA_BUS_ID=""
NVIDIA_INTEL_BUS_ID=""
NVIDIA_AMD_BUS_ID=""
NVIDIA_ENABLE="false"
NVIDIA_INCLUDE="false"

if ! has_nvidia; then
  echo "No NVIDIA GPU detected; skipping NVIDIA configuration."
else
  echo "NVIDIA GPU detected."
  echo "Select NVIDIA mode:"
  echo "  1) desktop (single NVIDIA GPU)"
  echo "  2) laptop-offload (Optimus/PRIME offload)"
  echo "  3) laptop-sync (PRIME sync)"
  echo "  4) skip (do not enable NVIDIA)"
  while true; do
    ask "Choice" "2" NVIDIA_MODE_CHOICE
    case "$NVIDIA_MODE_CHOICE" in
      1)
        NVIDIA_MODE="desktop"
        break
        ;;
      2)
        NVIDIA_MODE="laptop-offload"
        break
        ;;
      3)
        NVIDIA_MODE="laptop-sync"
        break
        ;;
      4)
        NVIDIA_MODE="desktop"
        NVIDIA_ENABLE="false"
        NVIDIA_INCLUDE="true"
        break
        ;;
      *) echo "That entry isn't valid. Choose a number from 1 to 4." >&2 ;;
    esac
  done

  if [[ "$NVIDIA_MODE_CHOICE" != "4" ]]; then
    NVIDIA_ENABLE="true"
    NVIDIA_INCLUDE="true"
    ask_yes_no "Use open kernel module (recommended for Turing+)" "y" NVIDIA_OPEN_YN
    [[ "$NVIDIA_OPEN_YN" == "true" ]] || NVIDIA_OPEN="false"

    if [[ "$NVIDIA_MODE" != "desktop" ]]; then
      detected_igpu="$(detect_igpu_busid || true)"
      NVIDIA_NVIDIA_BUS_ID="$(detect_nvidia_busid || true)"
      NVIDIA_INTEL_BUS_ID=""
      NVIDIA_AMD_BUS_ID=""
      if [[ "$detected_igpu" == intel:* ]]; then
        NVIDIA_INTEL_BUS_ID="${detected_igpu#intel:}"
      elif [[ "$detected_igpu" == amd:* ]]; then
        NVIDIA_AMD_BUS_ID="${detected_igpu#amd:}"
      fi

      if [[ -n "$NVIDIA_NVIDIA_BUS_ID" && ( -n "$NVIDIA_INTEL_BUS_ID" || -n "$NVIDIA_AMD_BUS_ID" ) ]]; then
        echo "Detected bus IDs:"
        echo "  NVIDIA: ${NVIDIA_NVIDIA_BUS_ID:-<missing>}"
        echo "  Intel iGPU: ${NVIDIA_INTEL_BUS_ID:-<none>}"
        echo "  AMD iGPU: ${NVIDIA_AMD_BUS_ID:-<none>}"
        ask_yes_no "Use detected bus IDs?" "y" USE_DETECTED_OK
        if [[ "$USE_DETECTED_OK" == "true" ]]; then
          USE_DETECTED="y"
        else
          USE_DETECTED="n"
        fi
      else
        USE_DETECTED="n"
      fi

      if [[ "$USE_DETECTED" =~ ^[Nn]$ ]]; then
        echo "Hybrid graphics requires bus IDs (format PCI:1:0:0)."
        ask "dGPU (NVIDIA) bus ID" "PCI:1:0:0" NVIDIA_NVIDIA_BUS_ID
        echo "Select iGPU type:"
        echo "  1) Intel"
        echo "  2) AMD"
        while true; do
          ask "Choice" "1" NVIDIA_IGPU_CHOICE
          case "$NVIDIA_IGPU_CHOICE" in
            1)
              ask "Intel iGPU bus ID" "PCI:0:2:0" NVIDIA_INTEL_BUS_ID
              NVIDIA_AMD_BUS_ID=""
              break
              ;;
            2)
              ask "AMD iGPU bus ID" "PCI:0:0:0" NVIDIA_AMD_BUS_ID
              NVIDIA_INTEL_BUS_ID=""
              break
              ;;
            *) echo "That entry isn't valid. Choose 1 or 2." >&2 ;;
          esac
        done
      fi
    fi
  fi
fi

###############################################################################
# 10) Remote snapshots (opt-in stub)
###############################################################################

echo ""
echo "Remote snapshot replication (advanced):"
echo "  Recommended: configure post-install (SSH hardening required)."
ask_yes_no "Enable remote btrbk replication now?" "n" SNAP_REMOTE_ENABLE
SNAP_REMOTE_TARGET=""
if [[ "$SNAP_REMOTE_ENABLE" == "true" ]]; then
  ask "Remote target (ssh://user@host/path)" "ssh://backup@backup-host/nyxos" SNAP_REMOTE_TARGET
  echo "⚠️  Ensure you harden SSH keys (restricted command=btrfs receive, no-pty, etc.) post-install."
fi

###############################################################################
# 11) Partitioning and formatting
###############################################################################

if [[ "$RUN_MODE" != "dry-run" ]]; then
  echo ""
  echo "Partitioning $DISK ..."

  DISK_REAL="$(readlink -f "$DISK" 2>/dev/null || true)"
  if [[ -n "$DISK_REAL" ]]; then
    disable_swap_on_disk "$DISK_REAL"
  else
    disable_swap_on_disk "$DISK"
  fi

wipefs -a "$DISK"
parted -s "$DISK" mklabel gpt

# Partition sizes:
# ESP: 512 MiB
# Swap: SWAP_SIZE_GIB (if enabled)
# Persist: PERSIST_SIZE_MIB (if enabled)
# Root: rest

ESP_START="1MiB"
ESP_END="513MiB"

parted -s "$DISK" mkpart ESP fat32 "$ESP_START" "$ESP_END"
parted -s "$DISK" set 1 esp on

CURRENT_START_MIB=513

if [[ "$SWAP_MODE" == "partition" && "$SWAP_SIZE_GIB" != "0" ]]; then
  SWAP_MIB=$(( SWAP_SIZE_GIB * 1024 ))
  SWAP_END_MIB=$(( CURRENT_START_MIB + SWAP_MIB ))
  SWAP_END="${SWAP_END_MIB}MiB"
  parted -s "$DISK" mkpart primary linux-swap "${CURRENT_START_MIB}MiB" "$SWAP_END"
  CURRENT_START_MIB="$SWAP_END_MIB"
fi

if [[ "$PERSIST_ENABLE" == "true" ]]; then
  PERSIST_END_MIB=$(( CURRENT_START_MIB + PERSIST_SIZE_MIB ))
  PERSIST_END="${PERSIST_END_MIB}MiB"
  parted -s "$DISK" mkpart primary "${CURRENT_START_MIB}MiB" "$PERSIST_END"
  CURRENT_START_MIB="$PERSIST_END_MIB"
fi

parted -s "$DISK" mkpart primary "${CURRENT_START_MIB}MiB" 100%

udevadm settle

# Determine partition numbers based on enabled partitions
ESP_PART="${DISK}${PART_PREFIX}1"
PART_NUM=2
if [[ "$SWAP_MODE" == "partition" && "$SWAP_SIZE_GIB" != "0" ]]; then
  SWAP_PART="${DISK}${PART_PREFIX}${PART_NUM}"
  PART_NUM=$(( PART_NUM + 1 ))
else
  SWAP_PART=""
fi
if [[ "$PERSIST_ENABLE" == "true" ]]; then
  PERSIST_PART="${DISK}${PART_PREFIX}${PART_NUM}"
  PART_NUM=$(( PART_NUM + 1 ))
else
  PERSIST_PART=""
fi
ROOT_PART="${DISK}${PART_PREFIX}${PART_NUM}"

mkfs.fat -F32 -n ESP "$ESP_PART"

if [[ -n "$SWAP_PART" ]]; then
  mkswap -L SWAP "$SWAP_PART"
fi

if [[ -n "$PERSIST_PART" ]]; then
  if [[ "$PERSIST_FSTYPE" == "btrfs" ]]; then
    mkfs.btrfs -f -L "$PERSIST_LABEL" "$PERSIST_PART"
  else
    mkfs.ext4 -F -L "$PERSIST_LABEL" "$PERSIST_PART"
  fi
fi

ROOT_DEVICE="$ROOT_PART"
LUKS_UUID=""
if [[ "$ENC_MODE" == "luks2" ]]; then
  if ! has_command cryptsetup; then
    echo "❌ cryptsetup is required for LUKS2 but is not available." >&2
    exit 1
  fi
  echo ""
  echo "Setting up LUKS2 container on ${ROOT_PART}..."
  setup_luks_container "$ROOT_PART" "$LUKS_MAPPER_NAME" "$LUKS_ALLOW_DISCARDS"
  ROOT_DEVICE="/dev/mapper/${LUKS_MAPPER_NAME}"
  LUKS_UUID="$(cryptsetup luksUUID "$ROOT_PART")"
  udevadm settle
  if [[ -z "$LUKS_GPG_DEVICE" || "$LUKS_GPG_DEVICE" == "/dev/disk/by-label/nixos" ]]; then
    LUKS_GPG_DEVICE="/dev/disk/by-uuid/${LUKS_UUID}"
  fi
fi

mkfs.btrfs -f -L nixos "$ROOT_DEVICE"

# Create subvolumes
mount "$ROOT_DEVICE" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
umount /mnt

MOUNT_OPTS="noatime,ssd,space_cache=v2,compress=zstd:3"
mount -o "$MOUNT_OPTS,subvol=@" "$ROOT_DEVICE" /mnt
mkdir -p /mnt/{boot,home,nix,etc/nixos}
mount -o "$MOUNT_OPTS,subvol=@home" "$ROOT_DEVICE" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@nix" "$ROOT_DEVICE" /mnt/nix
mount "$ESP_PART" /mnt/boot

if [[ -n "$PERSIST_PART" ]]; then
  mkdir -p /mnt/persist
  mount "$PERSIST_PART" /mnt/persist
  mkdir -p /mnt/persist/keys
  chmod 700 /mnt/persist/keys
fi

if [[ "$LUKS_GPG_ENABLE" == "true" && "$ENC_MODE" == "luks2" ]]; then
  echo ""
  echo "LUKS GPG keyfile setup:"
  mkdir -p /mnt/persist
  if [[ -n "$PERSIST_PART" ]]; then
    echo "Persist partition mounted at /mnt/persist."
  else
    echo "Mount your encrypted keyfile device at /mnt/persist before continuing."
  fi
  ask_yes_no "Pause to set up the encrypted keyfile now?" "y" PAUSE_KEYFILE
  if [[ "$PAUSE_KEYFILE" == "true" ]]; then
    cat <<EOF
Suggested steps (manual):
  install -d -m 0700 /mnt/persist/keys
  dd if=/dev/urandom of=/tmp/root.key bs=1 count=4096 status=none
  cryptsetup luksAddKey "${ROOT_PART}" /tmp/root.key
  gpg --encrypt --recipient "<YOUR_KEYID>" --output /mnt/persist/keys/root.key.gpg /tmp/root.key
  shred -u /tmp/root.key
  NOTE: Do not store plaintext key material on disk; only the encrypted .gpg file under /persist/keys.
EOF

    ask_yes_no "Run automated keyfile creation now?" "n" AUTO_KEYFILE
    if [[ "$AUTO_KEYFILE" == "true" ]]; then
      while true; do
        ask "GPG recipient (key ID/fingerprint/email)" "" GPG_RECIPIENT
        if [[ -n "$GPG_RECIPIENT" ]]; then
          break
        fi
        echo "That entry isn't valid. GPG recipient is required." >&2
      done
      install -d -m 0700 /mnt/persist/keys
      TMP_KEY="$(mktemp /tmp/nyxos-luks-key.XXXXXX)"
      dd if=/dev/urandom of="$TMP_KEY" bs=1 count=4096 status=none
      cryptsetup luksAddKey "$ROOT_PART" "$TMP_KEY"
      gpg --batch --yes --encrypt --recipient "$GPG_RECIPIENT" \
        --output /mnt/persist/keys/root.key.gpg "$TMP_KEY"
      shred -u "$TMP_KEY"
      echo "Encrypted keyfile written to /mnt/persist/keys/root.key.gpg"
    else
      read -r -p "Press Enter once finished with keyfile setup..." _
      echo "Verify /mnt/persist/keys/root.key.gpg exists and is encrypted before continuing."
    fi
  else
    echo "WARNING: Keyfile setup was skipped. Ensure you add an encrypted keyfile and LUKS keyslot post-install; misconfiguration can lock you out."
  fi
fi
fi

###############################################################################
# 12) Generate hardware config
###############################################################################

if [[ "$RUN_MODE" != "dry-run" ]]; then
  echo ""
  echo "Generating hardware-configuration.nix..."
  nixos-generate-config --root /mnt
fi

###############################################################################
# 13) Write answers file
###############################################################################

echo ""
echo "Writing answers file..."
NVIDIA_BLOCK=""
if [[ "$NVIDIA_INCLUDE" == "true" ]]; then
  NVIDIA_BLOCK=$(
    cat <<EOF_NVIDIA
  nvidia = {
    enable = ${NVIDIA_ENABLE};
    mode = "${NVIDIA_MODE}";
    open = ${NVIDIA_OPEN};
    nvidiaBusId = "${NVIDIA_NVIDIA_BUS_ID}";
    intelBusId = "${NVIDIA_INTEL_BUS_ID}";
    amdgpuBusId = "${NVIDIA_AMD_BUS_ID}";
  };
EOF_NVIDIA
  )
fi

cat > "${ANSWERS_ROOT}/nyxos-install.nix" <<EOF
{
  userName = "${USERNAME}";
  hostName = "${HOSTNAME}";
  timeZone = "${TIMEZONE}";

  keyboard = {
    enable = ${KEYBOARD_ENABLE};
    preset = "${KEYBOARD_PRESET}";
  };

  mac = {
    mode = "${MAC_MODE}";
    interface = "${MAC_INTF}";
    address = "${MAC_ADDR}";
  };

  boot = {
    mode = "${BOOT_MODE}";
  };

  trust.phase = "${TRUST_PHASE}";

  hardwareAuth = {
    trezor = {
      present = ${HWAUTH_TREZOR_PRESENT};
      model = "${HWAUTH_TREZOR_MODEL}";
    };
    fido2 = {
      present = ${HWAUTH_FIDO2_PRESENT};
    };
  };

  ssh = {
    identity = "${SSH_IDENTITY}";
  };

  my.ssh = {
    enable = ${SSH_POLICY_ENABLE};

    client = {
      profile = "${SSH_PROFILE}";
      features = ${SSH_FEATURES_NIX};
      onePasswordAgent.enable = ${SSH_ONEPASSWORD_ENABLE};
    };

    knownHosts.enable = ${SSH_KNOWNHOSTS_ENABLE};
  };

  snapshots = {
    retention = ${SNAP_RETENTION};
    schedule = "${SNAP_SCHEDULE}";
    prePostRebuild = ${SNAP_PREPOST};
    remote = {
      enable = ${SNAP_REMOTE_ENABLE};
      target = "${SNAP_REMOTE_TARGET}";
    };
  };

  storage.trim = {
    enable = ${TRIM_ENABLE};
    interval = "${TRIM_INTERVAL}";
    allowDiscardsInLuks = ${LUKS_ALLOW_DISCARDS};
  };

  encryption = {
    mode = "${ENC_MODE}";
  };

  luksGpg = {
    enable = ${LUKS_GPG_ENABLE};
    device = "${LUKS_GPG_DEVICE}";
    mapperName = "${LUKS_GPG_MAPPER}";
    encryptedKeyFile = "${LUKS_GPG_KEYFILE}";
    encryptedKeyDevice = "${LUKS_GPG_KEY_DEVICE}";
    encryptedKeyFsType = "${LUKS_GPG_KEY_FSTYPE}";
  };

  swap = {
    mode = "${SWAP_MODE}";
    sizeGiB = ${SWAP_SIZE_GIB};
  };

  profile.system = "${SYSTEM_PROFILE}";

  gaming = {
    steam = ${GAME_STEAM};
    gamemode = ${GAME_GAMEMODE};
    gamescope = ${GAME_GAMESCOPE};
    lutris = ${GAME_LUTRIS};
    lutrisRsi = ${GAME_RSI};
    wine = ${GAME_WINE};
    emulationstation = ${GAME_EMULATIONSTATION};
  };

  hardware = {
    cpuVendor = "${CPU_VENDOR}";
    gpu = {
      hasNvidia = ${GPU_HAS_NVIDIA};
      hasAmd = ${GPU_HAS_AMD};
      hasIntel = ${GPU_HAS_INTEL};
      primary = "${GPU_PRIMARY}";
    };
  };

${NVIDIA_BLOCK}
}
EOF

###############################################################################
# 14) Copy repo and install
###############################################################################

if [[ "$RUN_MODE" == "dry-run" ]]; then
  echo ""
  echo "Dry-run build (toplevel only)..."
  ensure_build_dir
  nix --extra-experimental-features "nix-command flakes" \
    build ".#nixosConfigurations.${BUILD_TARGET}.config.system.build.toplevel" \
    -L --show-trace
  echo ""
  echo "✅ Dry-run complete."
  exit 0
fi

echo ""
echo "Copying repository to /mnt/etc/nixos..."
rsync -a --exclude='.git' --exclude='result' ./ /mnt/etc/nixos/

echo ""
echo "Installing..."
ensure_build_dir
nixos-install --no-root-passwd --flake "/mnt/etc/nixos#${BUILD_TARGET}"

echo ""
echo "✅ Done! Set your password after reboot."
