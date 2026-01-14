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
ask "Choice" "1" PROFILE_CHOICE
SYSTEM_PROFILE="balanced"
case "$PROFILE_CHOICE" in
  2) SYSTEM_PROFILE="latency" ;;
  3) SYSTEM_PROFILE="throughput" ;;
  4) SYSTEM_PROFILE="battery" ;;
esac

###############################################################################
# 9) Remote snapshots (opt-in stub)
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
# 10) Partitioning and formatting
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
# 11) Generate hardware config
###############################################################################

echo ""
echo "Generating hardware-configuration.nix..."
nixos-generate-config --root /mnt

###############################################################################
# 12) Write answers file
###############################################################################

echo ""
echo "Writing answers file..."
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
}
EOF

###############################################################################
# 13) Copy repo and install
###############################################################################

echo ""
echo "Copying repository to /mnt/etc/nixos..."
rsync -a --exclude='.git' --exclude='result' ./ /mnt/etc/nixos/

echo ""
echo "Installing..."
nixos-install --no-root-passwd --flake /mnt/etc/nixos#nyx

echo ""
echo "✅ Done! Set your password after reboot."
