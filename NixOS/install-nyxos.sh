#!/usr/bin/env bash

# NyxOS Dynamic Installation Script
# This script guides you through installing NyxOS with custom settings

echo "🌟 NyxOS Dynamic Installation"
echo "================================"
echo ""

# Function to prompt for input with default
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local variable="$3"
    
    read -p "$prompt [$default]: " input
    
    if [ -z "$input" ]; then
        eval "$variable='$default'"
    else
        eval "$variable='$input'"
    fi
}

# Function to prompt for password
prompt_password() {
    local prompt="$1"
    local variable="$3"
    
    while true; do
        read -s -p "$prompt: " password
        echo ""
        read -s -p "Confirm $prompt: " password2
        echo ""
        
        if [ "$password" = "$password2" ]; then
            eval "$variable='$password'"
            break
        else
            echo "Passwords do not match. Please try again."
        fi
    done
}

# Gather user information
echo "📋 User Configuration"
echo "--------------------"

# Username
prompt_with_default "Enter username" "ashy" "USERNAME"

# Hostname
prompt_with_default "Enter hostname" "nyx" "HOSTNAME"

# Timezone
prompt_with_default "Enter timezone (e.g., America/New_York)" "UTC" "TIMEZONE"

# User password
prompt_password "Enter user password" "USER_PASSWORD"

# Root password
prompt_password "Enter root password" "ROOT_PASSWORD"

# MAC address
prompt_with_default "Enter network interface MAC address (or leave blank)" "" "MAC_ADDRESS"

# Confirm settings
echo ""
echo "🔍 Installation Settings:"
echo "----------------------"
echo "Username: $USERNAME"
echo "Hostname: $HOSTNAME"
echo "Timezone: $TIMEZONE"
echo "User Password: ********"
echo "Root Password: ********"
echo "MAC Address: ${MAC_ADDRESS:-Not set}"
echo ""

read -p "Continue with installation? (y/n) " -n 1 -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
echo "Installation cancelled."
    exit 1
fi
echo ""

# Create temporary configuration with user settings
echo "🛠️ Creating custom configuration..."

# Create a temporary directory for custom config
mkdir -p /tmp/nyxos-install

# Create a custom configuration.nix with user settings
cat > /tmp/nyxos-install/configuration.nix << EOF
{ config, pkgs, ... }:

let
  # NETWORKING & SECURITY
  # ==========================================
  networking.hostName = "nyx";
  networking.networkmanager.enable = true;
  networking.enableIPv6 = false;

  # Set MAC address if provided
  ${if [ -n "$MAC_ADDRESS" ]; then
    echo "networking.interfaces.enp1s0.macAddress = \"$MAC_ADDRESS\";"
  else
    echo "# No custom MAC address set"
  fi}
=======
  # ==========================================
  # NETWORKING & SECURITY
  # ==========================================
  networking.hostName = "$HOSTNAME";
  networking.networkmanager.enable = true;
  networking.enableIPv6 = false;

  # Set MAC address if provided
  ${if [ -n "$MAC_ADDRESS" ]; then
    echo "networking.interfaces.enp1s0.macAddress = \"$MAC_ADDRESS\";"
  else
    echo "# No custom MAC address set"
  fi}

  # Timezone
  time.timeZone = "$TIMEZONE";

  # Privacy-focused DNS servers
  networking.nameservers = [
    "142.242.2.2"
    "94.140.14.14"
    "94.140.15.15"
    "149.112.112.112"
    "9.9.9.9"
    "1.1.1.2"
    "1.0.0.2"
    "1.1.1.1"
    "1.0.0.1"
  ];User settings from installation
  username = "$USERNAME";
  userPassword = "$USER_PASSWORD";
  rootPassword = "$ROOT_PASSWORD";
  macAddress = "${MAC_ADDRESS}";
in
{
  imports = [ ./hardware-configuration.nix ];

  # ==========================================
  # KERNEL & BOOT
  # ==========================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "amd_pstate=active"
    "amdgpu.ppfeaturemask=0xffffffff"
    "quiet"
    "splash"
    "nowatchdog"
    "nmi_watchdog=0"
    "tsc=reliable"
  ];
  boot.plymouth.enable = true;

  # Kernel sysctl optimizations
  boot.kernel.sysctl = {
    "kernel.kptr_restrict" = 1;
    "fs.protected_hardlinks" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 1;
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
  };

  # ==========================================
  # NETWORKING & SECURITY
  # ==========================================
  networking.hostName = "nyx";
  networking.networkmanager.enable = true;
  networking.enableIPv6 = false;

  # Set MAC address if provided
  ${if [ -n "$MAC_ADDRESS" ]; then
    echo "networking.interfaces.enp1s0.macAddress = \"$MAC_ADDRESS\";"
  else
    echo "# No custom MAC address set"
  fi}

  # ==========================================
  # USERS & SHELLS
  # ==========================================
  users.users.\${username} = {
    isNormalUser = true;
    description = \${username};
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "render" ];
    shell = pkgs.fish;
    createHome = true;
    initialPassword = userPassword;
  };

  # Root password
  users.users.root.initialPassword = rootPassword;

  programs.fish.enable = true;
  programs.bash.enable = true;

  # ==========================================
  # SYSTEM OPTIMIZATIONS (PHASE 3)
  # ==========================================
  boot.systemd.enableParallelStartup = true;
  boot.systemd.defaultTimeoutStartSec = "5s";
  boot.systemd.defaultTimeoutStopSec = "3s";

  boot.systemd.userServices = {
    enable = true;
    defaultLimitNOFILE = 65536;
    defaultLimitNPROC = 16384;
  };

  boot.systemd.journald = {
    compress = true;
    maxFileSize = "50M";
    rateLimitInterval = "30s";
    rateLimitBurst = 1000;
  };

  # Advanced memory management
  boot.kernel.sysctl = {
    "kernel.shmmni" = 4096;
    "vm.nr_hugepages" = 128;
    "vm.hugetlb_shm_group" = 0;
    "vm.overcommit_memory" = 1;
    "vm.overcommit_ratio" = 50;
    "vm.zone_reclaim_mode" = 0;
  };

  # I/O Scheduler Optimization
  boot.extraModprobeConfig = ''
    options elevator=bfq
    options scsi_mod.use_blk_mq=1
  '';

  # Advanced Network Configuration
  networking.kernel.sysctl = {
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
  };

  # Power Management
  powerManagement = {
    cpuFreqGovernor = "performance";
    enable = true;
  };

  # ==========================================
  # SERVICE OPTIMIZATIONS (PHASE 2)
  # ==========================================
  services = {
    ratbagd.enable = true;
    power-profiles-daemon = {
      enable = true;
      defaultProfile = "performance";
    };
    upower = {
      enable = true;
      criticalPowerAction = "HybridSleep";
      usePercentageForPolicy = true;
      percentageLow = 20;
      percentageCritical = 5;
      percentageAction = 3;
    };
    gvfs.enable = true;
    tumbler.enable = true;
    gnome.evolution-data-server.enable = true;
    gnome.gnome-keyring.enable = true;
  };

  security.pam.services.login.enableGnomeKeyring = true;

  # ==========================================
  # DISPLAY & GRAPHICS (OPTIMIZED)
  # ==========================================
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    autoLogin = {
      enable = false;
    };
    theme = "breeze";
  };

  services.xserver.enable = false;
  programs.niri.enable = true;

  # ==========================================
  # AUDIO (OPTIMIZED)
  # ==========================================
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    realtime = true;
    config = {
      log-level = 2;
      default-clock.rate = 48000;
    };
  };

  # ==========================================
  # ADVANCED MONITORING SERVICES
  # ==========================================
  services = {
    netdata = {
      enable = true;
      settings = {
        bind-to = "127.0.0.1";
        port = 19999;
        memory-mode = "ram";
        update-every = 1;
        history = 3600;
      };
    };

    prometheus-node-exporter = {
      enable = true;
      port = 9100;
      collectSystemdUnits = true;
      collectBtrfs = true;
    };

    grafana = {
      enable = true;
      port = 3000;
      plugins = [ "grafana-clock-panel" "grafana-simple-json-datasource" ];
    };
  };

  # ==========================================
  # SYSTEM PACKAGES
  # ==========================================
  environment.systemPackages = with pkgs; [
    # Custom Scripts
    # g502Manager
    # aichatSwap

    # Core Utils
    git curl wget micro
    unzip unrar p7zip
    libnotify wl-clipboard cliphist
    grim slurp
    udiskie

    # File Management
    xfce.thunar xfce.thunar-volman engrampa

    # Browsers
    brave firefox

    # Audio/Video
    pwvucontrol pavucontrol playerctl ffmpeg mpv
    gst_all_1.gstreamer gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly gst_all_1.gst-libav

    # Python / AI / Data
    (python311.withPackages (ps: with ps; [ pygobject3 numpy pandas ]))

    # Terminal
    eza lsd bat fzf zoxide starship ripgrep fd jq age gum glow trash-cli
    fastfetch macchina btop

    # Gaming
    dualsensectl libratbag ratbagd mangohud

    # Theming / Fonts
    bibata-cursors
    (nerdfonts.override { fonts = [ "FiraCode" "Hack" "JetBrainsMono" "Meslo" "CascadiaCode" "Hermit" "Inconsolata" "Terminus" ]; })
    noto-fonts-cjk-sans noto-fonts-emoji

    # Monitoring
    sysstat iotop iftop nmon bpytop powertop
    netdata prometheus-node-exporter grafana

    # Btrfs tools
    btrfs-progs btrbk snapper
  ];

  services.udev.packages = [ pkgs.game-devices-udev-rules ];
  system.stateVersion = "25.11";
}
EOF

# Create hardware configuration
cat > /tmp/nyxos-install/hardware-configuration.nix << 'EOF'
{ config, pkgs, ... }: {
  boot.initrd.availableKernelModules = [ "ahci" "xhci_pci" "usbhid" "sd_mod" "rtsx_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/sda1";
    fsType = "btrfs";
    options = [
      "noatime"
      "nodiratime"
      "compress=zstd:3"
      "space_cache=v2"
      "ssd"
      "commit=120"
      "thread_pool=4"
      "autodefrag"
    ];
  };
}
EOF

# Create home configuration for the user
cat > /tmp/nyxos-install/home-${USERNAME}.nix << EOF
{ config, pkgs, lib, ... }:

{
  home.stateVersion = "25.11";
  home.username = "${USERNAME}";
  home.homeDirectory = "/home/${USERNAME}";

  imports = [
    # Core definitions
    ./modules/home/options.nix
    ./modules/home/shells.nix
    ./modules/home/niri-shared.nix

    # Apps & Terminals
    ./modules/home/apps/brave-webapps.nix
    ./modules/home/apps/btop.nix
    ./modules/home/apps/cava.nix
    ./modules/home/terminals/kitty.nix

    # Panels
    ./modules/noctalia/default.nix
    ./modules/waybar/default.nix
  ];

  my.desktop = {
    enable = true;
    panel = "noctalia";
    terminal = "kitty";
  };

  programs.home-manager.enable = true;

  home.packages = with pkgs; [
    # Core
    kitty alacritty
    niri
    thunar

    # Notifications/Wallpaper
    swww
    mako

    # AI
    aichat

    # Btrfs tools
    btrfs-progs
    btrbk
    snapper

    # Monitoring
    sysstat
    iotop
    iftop
    nmon
    bpytop
    powertop
  ];
}
EOF

# Create a simple installation script
cat > /tmp/nyxos-install/install.sh << 'EOF'
#!/usr/bin/env bash
set -e

echo "🚀 NyxOS Installation Starting..."
echo "================================"

# Partition the disk
if [ ! -b /dev/nvme0n1 ]; then
    echo "Using /dev/sda as fallback"
    DISK="/dev/sda"
else
    DISK="/dev/nvme0n1"
fi

echo "Partitioning $DISK..."
parted --script $DISK \
    mklabel gpt \
    mkpart ESP fat32 1MiB 512MiB \
    set 1 esp on \
    mkpart primary 512MiB 100%

# Format partitions
echo "Formatting partitions..."
mkfs.fat -F32 ${DISK}p1
mkfs.btrfs -L nixos ${DISK}p2

# Mount filesystems
echo "Mounting filesystems..."
mount ${DISK}p2 /mnt
mkdir -p /mnt/boot
mount ${DISK}p1 /mnt/boot

# Install NixOS
echo "Installing NixOS..."
nixos-install --flake /tmp/nyxos-install#nyx

echo "✅ Installation complete!"
echo "Please reboot and enjoy your optimized NyxOS system."
EOF

chmod +x /tmp/nyxos-install/install.sh

echo "📁 Installation files created in /tmp/nyxos-install/"
echo ""
echo "💡 Next Steps:"
echo "1. Boot from NixOS minimal ISO"
echo "2. Copy these files to the live system"
echo "3. Run: bash /tmp/nyxos-install/install.sh"
echo "4. Follow the prompts to complete installation"
echo ""
echo "🎉 Your custom NyxOS will be installed with:"
echo "   - Username: $USERNAME"
echo "   - Hostname: $HOSTNAME"
echo "   - Timezone: $TIMEZONE"
echo "   - All Phase 1, 2, and 3 optimizations"
echo "   - Btrfs with optimal settings"
echo "   - Monitoring tools pre-installed"
echo "   - Privacy-focused DNS servers"
echo "   - Custom MAC address: ${MAC_ADDRESS:-Not set}"