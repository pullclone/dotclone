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
  read -r -p "$prompt [${default}]: " val
  val="${val:-$default}"
  case "$val" in
    y|Y) eval "$var_name='true'" ;;
    n|N) eval "$var_name='false'" ;;
    *) echo "❌ Please answer y or n." >&2; exit 1 ;;
  esac
}

require_int() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^-?[0-9]+$ ]]; then
    echo "❌ $name must be an integer (got: $value)" >&2
    exit 1
  fi
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

###############################################################################
# 0) Disk selection
###############################################################################

echo ""
echo "Available block devices:"
lsblk -d -p -o NAME,SIZE,MODEL

ask "Enter disk to install onto (e.g. /dev/sda or /dev/nvme0n1)" "/dev/sda" DISK
PART_PREFIX="$(compute_part_prefix "$DISK")"

echo ""
echo "⚠️  This will destroy ALL data on: $DISK"
read -r -p "Type YES to continue: " CONFIRM
if [[ "$CONFIRM" != "YES" ]]; then
  echo "Aborted." >&2
  exit 1
fi

###############################################################################
# 1) Collect base answers
###############################################################################

ask "Enter Username" "ashy" USERNAME
if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "❌ Invalid username." >&2; exit 1
fi

ask "Enter Hostname" "nyx" HOSTNAME

ask "Enter Timezone (e.g. UTC or America/Denver)" "UTC" TIMEZONE
if [[ ! -e "/usr/share/zoneinfo/$TIMEZONE" ]]; then
  echo "❌ Timezone not found: $TIMEZONE" >&2
  exit 1
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
ask "Choice" "1" MAC_CHOICE

MAC_MODE="default"
MAC_INTF=""
MAC_ADDR=""
case "$MAC_CHOICE" in
  2) MAC_MODE="random" ;;
  3) MAC_MODE="stable" ;;
  4)
    MAC_MODE="fixed"
    ask "Interface (e.g. enp1s0)" "enp1s0" MAC_INTF
    ask "Address (e.g. 00:11:22:33:44:55)" "" MAC_ADDR
    if [[ ! "$MAC_ADDR" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
      echo "❌ Invalid MAC address." >&2
      exit 1
    fi
    ;;
esac

###############################################################################
# 3) Boot mode + trust phase
###############################################################################

echo ""
echo "Select Boot Mode:"
echo "  1) Secure Boot (recommended) — Lanzaboote (requires firmware SB enforcing)"
echo "  2) UKI baseline (dev-friendly) — systemd-boot/UKI"
ask "Choice" "2" BOOT_CHOICE
BOOT_MODE="uki"
case "$BOOT_CHOICE" in
  1) BOOT_MODE="secureboot" ;;
  2) BOOT_MODE="uki" ;;
esac

echo ""
echo "Select Trust Phase:"
echo "  1) dev      (TPM deferred, no SB enforcement assertions)"
echo "  2) enforced (SB/TPM assertions enabled; TPM enrollment still manual)"
ask "Choice" "1" TRUST_CHOICE
TRUST_PHASE="dev"
case "$TRUST_CHOICE" in
  2) TRUST_PHASE="enforced" ;;
esac

###############################################################################
# 4) Snapshots (btrbk retention)
###############################################################################

echo ""
echo "Btrfs snapshot retention (btrbk):"
echo "  Recommended: 7–15"
echo "  Default: 11"
echo "  -1 = not configured (NyxOS will not manage snapshots)"
echo "   0 = disable snapshots explicitly"
ask "Retention count" "11" SNAP_RETENTION
require_int "Snapshot retention" "$SNAP_RETENTION"

if (( SNAP_RETENTION > 33 )); then
  echo ""
  echo "⚠️  You entered $SNAP_RETENTION snapshots."
  echo "    This is more than a reasonable default and may consume significant space."
  read -r -p "Continue with $SNAP_RETENTION? (y/N): " ok
  case "${ok:-N}" in
    y|Y) : ;;
    *) echo "Aborted." >&2; exit 1 ;;
  esac
fi

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

# If/when you add LUKS to the installer, this controls allowDiscards.
ask_yes_no "Allow discards through LUKS layer (future encrypted installs)?" "y" LUKS_ALLOW_DISCARDS

###############################################################################
# 6) Encryption intent (installer currently does unencrypted Btrfs)
###############################################################################

echo ""
echo "Encryption intent (installer currently uses unencrypted Btrfs root):"
echo "  1) none  (current installer behavior)"
echo "  2) luks2 (records intent; requires encrypted installer path)"
ask "Choice" "1" ENC_CHOICE
ENC_MODE="none"
case "$ENC_CHOICE" in
  2) ENC_MODE="luks2" ;;
esac

if [[ "$ENC_MODE" == "luks2" ]]; then
  echo ""
  echo "⚠️  Note: This installer does NOT yet perform LUKS setup."
  echo "    It will record encryption.mode=luks2 in the answers file for later."
fi

###############################################################################
# 7) Swap policy
###############################################################################

echo ""
echo "Swap configuration:"
echo "  1) partition (recommended for now; installer creates it)"
echo "  2) none      (installer will skip creating swap)"
ask "Choice" "1" SWAP_CHOICE
SWAP_MODE="partition"
case "$SWAP_CHOICE" in
  2) SWAP_MODE="none" ;;
esac

SWAP_SIZE_GIB="8"
if [[ "$SWAP_MODE" == "partition" ]]; then
  ask "Swap size in GiB" "8" SWAP_SIZE_GIB
  require_int "Swap size GiB" "$SWAP_SIZE_GIB"
  if (( SWAP_SIZE_GIB < 0 )); then
    echo "❌ Swap size must be >= 0" >&2; exit 1
  fi
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
ask "Choice" "1" PROFILE_CHOICE
SYSTEM_PROFILE="balanced"
case "$PROFILE_CHOICE" in
  2) SYSTEM_PROFILE="latency" ;;
  3) SYSTEM_PROFILE="throughput" ;;
  4) SYSTEM_PROFILE="battery" ;;
  5) SYSTEM_PROFILE="memory-saver" ;;
esac

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
  ask "Choice" "2" NVIDIA_MODE_CHOICE
  case "$NVIDIA_MODE_CHOICE" in
    2) NVIDIA_MODE="laptop-offload" ;;
    3) NVIDIA_MODE="laptop-sync" ;;
    4)
      NVIDIA_MODE="desktop"
      NVIDIA_ENABLE="false"
      NVIDIA_INCLUDE="true"
      ;;
    *) NVIDIA_MODE="desktop" ;;
  esac

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
        read -r -p "Use detected bus IDs? [Y/n]: " USE_DETECTED
        USE_DETECTED="${USE_DETECTED:-Y}"
      else
        USE_DETECTED="n"
      fi

      if [[ "$USE_DETECTED" =~ ^[Nn]$ ]]; then
        echo "Hybrid graphics requires bus IDs (format PCI:1:0:0)."
        ask "dGPU (NVIDIA) bus ID" "PCI:1:0:0" NVIDIA_NVIDIA_BUS_ID
        echo "Select iGPU type:"
        echo "  1) Intel"
        echo "  2) AMD"
        ask "Choice" "1" NVIDIA_IGPU_CHOICE
        case "$NVIDIA_IGPU_CHOICE" in
          2)
            ask "AMD iGPU bus ID" "PCI:0:0:0" NVIDIA_AMD_BUS_ID
            NVIDIA_INTEL_BUS_ID=""
            ;;
          *)
            ask "Intel iGPU bus ID" "PCI:0:2:0" NVIDIA_INTEL_BUS_ID
            NVIDIA_AMD_BUS_ID=""
            ;;
        esac
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

echo ""
echo "Partitioning $DISK ..."

wipefs -a "$DISK"
parted -s "$DISK" mklabel gpt

# Partition sizes:
# ESP: 512 MiB
# Swap: SWAP_SIZE_GIB (if enabled)
# Root: rest

ESP_START="1MiB"
ESP_END="513MiB"

parted -s "$DISK" mkpart ESP fat32 "$ESP_START" "$ESP_END"
parted -s "$DISK" set 1 esp on

ROOT_START="$ESP_END"

if [[ "$SWAP_MODE" == "partition" && "$SWAP_SIZE_GIB" != "0" ]]; then
  # swap end = esp end + swap size
  # use MiB math to avoid floating issues: 1GiB = 1024MiB
  SWAP_MIB=$(( SWAP_SIZE_GIB * 1024 ))
  SWAP_END_MIB=$(( 513 + SWAP_MIB ))
  SWAP_END="${SWAP_END_MIB}MiB"
  parted -s "$DISK" mkpart primary linux-swap "$ESP_END" "$SWAP_END"
  parted -s "$DISK" mkpart primary "$SWAP_END" 100%
else
  # no swap partition (or size 0)
  parted -s "$DISK" mkpart primary "$ESP_END" 100%
fi

udevadm settle

# Determine partition numbers for root depending on swap creation
ESP_PART="${DISK}${PART_PREFIX}1"
if [[ "$SWAP_MODE" == "partition" && "$SWAP_SIZE_GIB" != "0" ]]; then
  SWAP_PART="${DISK}${PART_PREFIX}2"
  ROOT_PART="${DISK}${PART_PREFIX}3"
else
  SWAP_PART=""
  ROOT_PART="${DISK}${PART_PREFIX}2"
fi

mkfs.fat -F32 -n ESP "$ESP_PART"

if [[ -n "$SWAP_PART" ]]; then
  mkswap -L SWAP "$SWAP_PART"
  swapon "$SWAP_PART"
fi

mkfs.btrfs -f -L nixos "$ROOT_PART"

# Create subvolumes
mount "$ROOT_PART" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
umount /mnt

MOUNT_OPTS="noatime,ssd,space_cache=v2,compress=zstd:3"
mount -o "$MOUNT_OPTS,subvol=@" "$ROOT_PART" /mnt
mkdir -p /mnt/{boot,home,nix,etc/nixos}
mount -o "$MOUNT_OPTS,subvol=@home" "$ROOT_PART" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@nix" "$ROOT_PART" /mnt/nix
mount "$ESP_PART" /mnt/boot

###############################################################################
# 12) Generate hardware config
###############################################################################

echo ""
echo "Generating hardware-configuration.nix..."
nixos-generate-config --root /mnt

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

cat > /mnt/etc/nixos/nyxos-install.nix <<EOF
{
  userName = "${USERNAME}";
  hostName = "${HOSTNAME}";
  timeZone = "${TIMEZONE}";

  mac = {
    mode = "${MAC_MODE}";
    interface = "${MAC_INTF}";
    address = "${MAC_ADDR}";
  };

  boot = {
    mode = "${BOOT_MODE}";
  };

  trust.phase = "${TRUST_PHASE}";

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

  swap = {
    mode = "${SWAP_MODE}";
    sizeGiB = ${SWAP_SIZE_GIB};
  };

  profile.system = "${SYSTEM_PROFILE}";

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

echo ""
echo "Copying repository to /mnt/etc/nixos..."
rsync -a --exclude='.git' --exclude='result' ./ /mnt/etc/nixos/

echo ""
echo "Installing..."
nixos-install --no-root-passwd --flake /mnt/etc/nixos#nyx

echo ""
echo "✅ Done! Set your password after reboot."
