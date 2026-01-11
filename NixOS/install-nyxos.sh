#!/usr/bin/env bash
set -euo pipefail

# NyxOS "Option B" Installer
# This script prepares the disk, generates the answer file, and installs the local flake.

echo "🌟 NyxOS Installer (Repo-Based)"
echo "================================="

# 1. Validation Helper
ask() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    read -r -p "$prompt [$default]: " val
    eval "$var_name='${val:-$default}'"
}

# 2. Collect Inputs
ask "Enter Username" "ashy" USERNAME
if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "❌ Invalid username." >&2; exit 1
fi

ask "Enter Hostname" "nyx" HOSTNAME
ask "Enter Timezone" "UTC" TIMEZONE
if [ ! -e "/usr/share/zoneinfo/$TIMEZONE" ]; then
  echo "❌ Timezone not found." >&2; exit 1
fi

echo ""
echo "Select MAC Address Policy:"
echo "  1) default (Let NetworkManager decide)"
echo "  2) random  (Randomize on every connection)"
echo "  3) stable  (Stable per-network randomization)"
echo "  4) fixed   (Spoof a specific address)"
ask "Choice" "1" MAC_CHOICE

MAC_MODE="default"
MAC_INTf=""
MAC_ADDR=""

case "$MAC_CHOICE" in
    2) MAC_MODE="random" ;;
    3) MAC_MODE="stable" ;;
    4)
       MAC_MODE="fixed"
       ask "Interface (e.g. enp1s0)" "enp1s0" MAC_INTF
       ask "Address (e.g. 00:11:22...)" "" MAC_ADDR
       if [[ ! "$MAC_ADDR" =~ ^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$ ]]; then
         echo "❌ Invalid MAC address." >&2; exit 1
       fi
       ;;
esac

# 3. Root Partition (Rest of disk)
parted -s "$DISK" mkpart primary 32.5GiB 100%

udevadm settle

# Format
mkfs.fat -F32 -n ESP "${DISK}${PART_PREFIX}1"

# We format swap and label it so the randomEncryption module finds it by label
mkswap -L SWAP "${DISK}${PART_PREFIX}2"

mkfs.btrfs -f -L nixos "${DISK}${PART_PREFIX}3"

# Mounts (Updated for partition numbers)
mount "${DISK}${PART_PREFIX}3" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@nix
umount /mnt

MOUNT_OPTS="noatime,ssd,space_cache=v2,compress=zstd:3"
mount -o "$MOUNT_OPTS,subvol=@" "${DISK}${PART_PREFIX}3" /mnt
mkdir -p /mnt/{boot,home,nix,etc/nixos}
mount -o "$MOUNT_OPTS,subvol=@home" "${DISK}${PART_PREFIX}3" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@nix" "${DISK}${PART_PREFIX}3" /mnt/nix

mount "${DISK}${PART_PREFIX}1" /mnt/boot

# 4. Generate Hardware Config
echo "Generating hardware-configuration.nix..."
nixos-generate-config --root /mnt

# 5. Write Answers File
echo "Writing answers file..."
cat > /mnt/etc/nixos/nyxos-install.nix <<EOF
{
  userName = "${USERNAME}";
  hostName = "${HOSTNAME}";
  timeZone = "${TIMEZONE}";
  mac = {
    mode = "${MAC_MODE}";
    interface = "${MAC_INTF:-}";
    address = "${MAC_ADDR:-}";
  };
}
EOF

# 6. Copy Repository
echo "Copying repository to /mnt/etc/nixos..."
# Copy current dir to /mnt/etc/nixos, excluding git/result
rsync -av --exclude='.git' --exclude='result' ./ /mnt/etc/nixos/

# 7. Install
echo "Installing..."
nixos-install --no-root-passwd --flake /mnt/etc/nixos#nyx

echo "✅ Done! Set your password after reboot."
