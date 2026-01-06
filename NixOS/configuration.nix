{ config, pkgs, lib, ... }:

let
  # POWER MANAGEMENT & PERFORMANCE
  # ==========================================
  powerManagement = {
    cpuFreqGovernor = "performance";
    enable = true;
  };

  # Performance monitoring tools
  environment.systemPackages = with pkgs; [
    sysstat
    iotop
    iftop
    nmon
    bpytop
    powertop
  ];
=======
  # ==========================================
  # POWER MANAGEMENT & PERFORMANCE
  # ==========================================
  powerManagement = {
    cpuFreqGovernor = "performance";
    enable = true;
  };

  # Performance monitoring tools
  environment.systemPackages = with pkgs; [
    sysstat
    iotop
    iftop
    nmon
    bpytop
    powertop
    # Advanced monitoring
    netdata
    prometheus-node-exporter
    grafana
  ];

  # ==========================================
  # ADVANCED MONITORING SERVICES
  # ==========================================
  services = {
    # Netdata - comprehensive real-time monitoring
    netdata = {
      enable = true;
      settings = {
        bind-to = "127.0.0.1";
        port = 19999;
        # Reduce resource usage
        memory-mode = "ram";
        update-every = 2;
      };
    };

    # Prometheus Node Exporter
    prometheus-node-exporter = {
      enable = true;
      port = 9100;
      collectSystemdUnits = true;
      collectBtrfs = true;
    };

    # Grafana - visualization (disabled by default)
    # grafana = {
    #   enable = true;
    #   port = 3000;
    # };
  };BTRFS OPTIMIZATIONS
  # ==========================================
  # Since you're using Btrfs, let's optimize it
  environment.etc."btrfs-maintenance.xml".text = ''
    <?xml version="1.0"?>
    <config>
      <periodic>
        <balance enabled="true" interval="monthly"/>
        <scrub enabled="true" interval="weekly" priority="nice"/>
        <trim enabled="true" interval="daily" priority="nice"/>
        <defrag enabled="false"/>
      </periodic>
    </config>
  '';
=======
  # ==========================================
  # BTRFS OPTIMIZATIONS (ENHANCED)
  # ==========================================
  # Since you're using Btrfs, let's optimize it
  environment.etc."btrfs-maintenance.xml".text = ''
    <?xml version="1.0"?>
    <config>
      <periodic>
        <balance enabled="true" interval="monthly" priority="nice">
          <filters>
            <usage>80</usage>
            <dusage>50</usage>
          </filters>
        </balance>
        <scrub enabled="true" interval="weekly" priority="nice" />
        <trim enabled="true" interval="daily" priority="nice" />
        <defrag enabled="false" />
      </periodic>
      <syslog>warning</syslog>
    </config>
  '';

  # Btrfs subvolume management
  systemd.services.btrfs-scrub = {
    description = "Btrfs Scrub Service";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.btrfs-progs}/bin/btrfs scrub start /";
    };
    timerConfig = {
      OnCalendar = "weekly";
      AccuracySec = "1h";
      Persistent = true;
    };
  };NETWORKING & SECURITY
  # ==========================================
  networking.hostName = "nyx";
  networking.networkmanager.enable = true;
  networking.enableIPv6 = false;

  # Custom Mac Address
  # networking.interfaces.wlp1s0.useDHCP = true;
  # networking.interfaces.wlp1s0.macAddress = "11:22:33:44:55:66";
  networking.interfaces.enp1s0.macAddress = "11:22:33:33:22:11";
=======
  # ==========================================
  # NETWORKING & SECURITY (OPTIMIZED)
  # ==========================================
  networking = {
    hostName = "nyx";
    networkmanager = {
      enable = true;
      # Performance optimizations
      settings = {
        main = {
          rc-manager = "file";
          plugins = [ "keyfile" ];
        };
        logging = {
          level = "INFO";
          domains = "ALL";
        };
      };
    };
    enableIPv6 = false;

    # Custom Mac Address
    # interfaces.wlp1s0.useDHCP = true;
    # interfaces.wlp1s0.macAddress = "11:22:33:44:55:66";
    interfaces.enp1s0.macAddress = "11:22:33:33:22:11";

    # Advanced network tuning
    kernel.sysctl = {
      # TCP optimizations
      "net.core.somaxconn" = 4096;
      "net.core.netdev_max_backlog" = 16384;
      "net.core.rmem_max" = 16777216;
      "net.core.wmem_max" = 16777216;
      "net.ipv4.tcp_rmem" = "4096 87380 16777216";
      "net.ipv4.tcp_wmem" = "4096 65536 16777216";
      "net.ipv4.tcp_max_syn_backlog" = 8192;
      "net.ipv4.tcp_slow_start_after_idle" = 0;
      "net.ipv4.tcp_tw_reuse" = 1;
      "net.ipv4.tcp_fin_timeout" = 30;
      "net.ipv4.tcp_keepalive_time" = 300;
      "net.ipv4.tcp_keepalive_probes" = 5;
      "net.ipv4.tcp_keepalive_intvl" = 30;
      # UDP optimizations
      "net.ipv4.udp_rmem_min" = 8192;
      "net.ipv4.udp_wmem_min" = 8192;
      # Network buffer optimizations
      "net.core.optmem_max" = 40960;
    };

    # DNS optimization
    extraHosts = ''
      127.0.0.1 localhost
      ::1       localhost
    '';
  };AUDIO
  # ==========================================
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
=======
  # ==========================================
  # AUDIO (OPTIMIZED)
  # ==========================================
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    # Performance optimizations
    realtime = true;
    systemSessionManager = true;
    config = {
      log-level = 2; # Reduce from default 3 to 2
      default-clock.rate = 48000;
      default-clock.quantum = 1024;
      default-clock.min-quantum = 32;
      default-clock.max-quantum = 2048;
      # Memory optimizations
      mem.allow-mlock = true;
      mem.mlock-all = false;
    };
  };DISPLAY & GRAPHICS
  # ==========================================
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Pure Wayland
  services.xserver.enable = false;

  # Niri System Module
  programs.niri.enable = true;
=======
  # ==========================================
  # DISPLAY & GRAPHICS (OPTIMIZED)
  # ==========================================
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    # Performance optimizations
    autoLogin = {
      enable = false; # Disable if not needed
      # user = "ashy"; # Uncomment if you want auto-login
    };
    theme = "breeze"; # Lightweight theme
    sessionCommand = "${pkgs.sddm}/bin/sddm";
    # Reduce memory usage
    displayServer = "wayland";
    # Optimize startup
    minimumVT = 1;
  };

  # Pure Wayland
  services.xserver.enable = false;

  # Niri System Module - optimized
  programs.niri = {
    enable = true;
    # Add any Niri-specific optimizations here
    # settings = { ... };
  };KERNEL & BOOT
  # ==========================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "amd_pstate=active" "amdgpu.ppfeaturemask=0xffffffff" "quiet" "splash" ];
  boot.plymouth.enable = true;
=======
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
    "nowatchdog"       # Disable watchdog timer for performance
    "nmi_watchdog=0"   # Disable NMI watchdog
    "tsc=reliable"     # Trust the TSC (Time Stamp Counter)
  ];
  # SYSTEM OPTIMIZATIONS
  # ==========================================
=======
  boot.plymouth.enable = true;

  # Kernel sysctl optimizations
  boot.kernel.sysctl = {
    # Performance-friendly security settings
    "kernel.kptr_restrict" = 1;
    "fs.protected_hardlinks" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 1;

    # Memory management tuning
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_ratio" = 10;
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_expire_centisecs" = 3000;
    "vm.dirty_writeback_centisecs" = 500;

    # Network optimizations
    "net.core.somaxconn" = 4096;
    "net.core.netdev_max_backlog" = 16384;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.ipv4.tcp_rmem" = "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = "4096 65536 16777216";
    "net.ipv4.tcp_max_syn_backlog" = 8192;
    "net.ipv4.tcp_slow_start_after_idle" = 0;
    "net.ipv4.tcp_tw_reuse" = 1;
    "net.ipv4.tcp_fin_timeout" = 30;
  };

  # ==========================================
  # SYSTEM OPTIMIZATIONS
  # ====================================================================================
  # SYSTEM OPTIMIZATIONS
  # ==========================================
  # Enable parallel service startup
  boot.systemd.enableParallelStartup = true;

  # Reduce boot timeouts for faster startup
  boot.systemd.defaultTimeoutStartSec = "5s";
  boot.systemd.defaultTimeoutStopSec = "3s";

  # Optimize resource limits
  boot.systemd.userServices = {
    enable = true;
    defaultLimitNOFILE = 65536;
    defaultLimitNPROC = 16384;
  };

  # Journal optimizations
  boot.systemd.journald = {
    compress = true;
    maxFileSize = "50M";
    rateLimitInterval = "30s";
    rateLimitBurst = 1000;
  };--- 1. G502 MANAGER SCRIPT ---
  g502Manager = pkgs.writeShellScriptBin "g502-manager" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Configuration
    MOUSE_NAME="Logitech G502"
    TOTAL_PROFILES=5
    CONFIG_DIR="''${XDG_CONFIG_HOME:-$HOME/.config}/g502-profiles"
    STATE_FILE="$CONFIG_DIR/current_profile"

    mkdir -p "$CONFIG_DIR"
    if [[ ! -f "$STATE_FILE" ]]; then echo "1" > "$STATE_FILE"; fi

    get_current_profile() {
        if [[ -f "$STATE_FILE" ]]; then cat "$STATE_FILE"; else echo "0"; fi
    }

    set_profile() {
        local profile=$1
        # Use ratbagctl to set profile
        if ${pkgs.libratbag}/bin/ratbagctl "$MOUSE_NAME" profile active set "$profile" 2>/dev/null; then
            echo "$profile" > "$STATE_FILE"
            ${pkgs.libnotify}/bin/notify-send "G502 Profile" "Switched to Profile $profile" -t 1000
        else
            echo "Error: Failed to switch to profile $profile" >&2
        fi
    }

    cycle_profile() {
        local direction=$1
        local current=$(get_current_profile)
        local new_profile
        if [[ "$direction" == "next" ]]; then
            new_profile=$(( (current + 1) % TOTAL_PROFILES ))
        else
            new_profile=$(( (current + TOTAL_PROFILES - 1) % TOTAL_PROFILES ))
        fi
        set_profile "$new_profile"
    }

    case "''${1:-}" in
        next) cycle_profile "next" ;;
        prev) cycle_profile "prev" ;;
        set)  set_profile "$2" ;;
        get)  get_current_profile ;;
        setup)
            echo "Configuring G502 Hardware Profiles via Ratbag..."
            RATBAG="${pkgs.libratbag}/bin/ratbagctl"

            # Profile 0: Desktop
            $RATBAG "$MOUSE_NAME" profile 0 button 4 action set key F13
            $RATBAG "$MOUSE_NAME" profile 0 button 5 action set key KEY_LEFTALT
            $RATBAG "$MOUSE_NAME" profile 0 button 6 action set key F14
            $RATBAG "$MOUSE_NAME" profile 0 button 7 action set key F15
            $RATBAG "$MOUSE_NAME" profile 0 button 8 action set key F16
            $RATBAG "$MOUSE_NAME" profile 0 button 9 action set key F23

            # Profile 1: Creative
            $RATBAG "$MOUSE_NAME" profile 1 button 4 action set key F17
            $RATBAG "$MOUSE_NAME" profile 1 button 5 action set key KEY_LEFTALT
            $RATBAG "$MOUSE_NAME" profile 1 button 6 action set key F18
            $RATBAG "$MOUSE_NAME" profile 1 button 7 action set key F19
            $RATBAG "$MOUSE_NAME" profile 1 button 8 action set key F20
            $RATBAG "$MOUSE_NAME" profile 1 button 9 action set key F23

            # Profile 2: Extended
            $RATBAG "$MOUSE_NAME" profile 2 button 4 action set key F21
            $RATBAG "$MOUSE_NAME" profile 2 button 5 action set key KEY_LEFTALT
            $RATBAG "$MOUSE_NAME" profile 2 button 6 action set key F22
            $RATBAG "$MOUSE_NAME" profile 2 button 7 action set key F23
            $RATBAG "$MOUSE_NAME" profile 2 button 8 action set key F24
            $RATBAG "$MOUSE_NAME" profile 2 button 9 action set key F23

            # Profile 3: Gaming
            $RATBAG "$MOUSE_NAME" profile 3 button 4 action set key KEY_C
            $RATBAG "$MOUSE_NAME" profile 3 button 5 action set key KEY_X
            $RATBAG "$MOUSE_NAME" profile 3 button 6 action set key KEY_V
            $RATBAG "$MOUSE_NAME" profile 3 button 7 action set key KEY_B
            $RATBAG "$MOUSE_NAME" profile 3 button 8 action set key KEY_Z
            $RATBAG "$MOUSE_NAME" profile 3 button 9 action set key KEY_TAB

            # Profile 4: Media
            $RATBAG "$MOUSE_NAME" profile 4 button 4 action set key KEY_PLAYPAUSE
            $RATBAG "$MOUSE_NAME" profile 4 button 5 action set key KEY_LEFTALT
            $RATBAG "$MOUSE_NAME" profile 4 button 6 action set key KEY_NEXTSONG
            $RATBAG "$MOUSE_NAME" profile 4 button 7 action set key KEY_PREVIOUSSONG
            $RATBAG "$MOUSE_NAME" profile 4 button 8 action set key KEY_VOLUMEDOWN
            $RATBAG "$MOUSE_NAME" profile 4 button 9 action set key KEY_MUTE
            $RATBAG "$MOUSE_NAME" profile 4 button 10 action set key KEY_VOLUMEUP

            echo "G502 Configuration Complete."
            ;;
        *) echo "Usage: g502-manager {next|prev|set N|get|setup}" ;;
    esac
  '';

  # --- 2. AI CHAT SWAPPER ---
  aichatSwap = pkgs.writeShellScriptBin "aichat-swap" ''
    #!/usr/bin/env bash
    set -e

    VERSION="1.1.0"
    BASE_DIR="''${AICHAT_CONF_DIR:-''${XDG_CONFIG_HOME:-$HOME/.config}/aichat}"
    DIR="$BASE_DIR"
    CURRENT_FILE="$DIR/current"

    IDS=(c g m o)
    NAMES=(altostrat alpha lechat stargate)

    _msg() { echo ">> $*"; }

    _get_name() {
        local target="$1" i
        for i in "''${!IDS[@]}"; do
            [[ "''${IDS[$i]}" == "$target" ]] && echo "''${NAMES[$i]}" && return 0
        done
        echo "unknown"
        return 1
    }

    _show_help() {
        echo "Usage: aichat-swap [options] <command|id>"
        echo "Commands: list, status, init"
    }

    init() {
        mkdir -p "$DIR"
        touch "$DIR/config.yaml"
        for id in "''${IDS[@]}"; do
            [[ -f "$DIR/$id.config.yaml" ]] || touch "$DIR/$id.config.yaml"
        done
        _msg "Init complete."
    }

    CMD="''${1:-status}"

    case "$CMD" in
        help|--help|-h) _show_help; exit 0 ;;
        init) init; exit 0 ;;
        status)
            if [[ -f "$CURRENT_FILE" ]]; then
                curr=$(head -n 1 "$CURRENT_FILE")
                name=$(_get_name "$curr")
                _msg "Active: $name [$curr]"
            else
                _msg "No active profile."
            fi
            exit 0 ;;
        list)
            echo "Available Profiles:"
            for i in "''${!IDS[@]}"; do
                printf "  [%s] %s\n" "''${IDS[$i]}" "''${NAMES[$i]}"
            done
            exit 0 ;;
    esac

    TARGET="$1"
    valid=false
    for i in "''${!IDS[@]}"; do [[ "$TARGET" == "''${IDS[$i]}" ]] && valid=true && break; done

    if ! $valid; then
        _msg "Unknown profile or command: $TARGET"
        exit 1
    fi

    SRC="$DIR/$TARGET.config.yaml"
    if [[ ! -f "$SRC" ]]; then
        _msg "Target profile missing: $SRC"
        exit 1
    fi

    cp "$SRC" "$DIR/config.yaml"
    echo "$TARGET" > "$CURRENT_FILE"
    _msg "Switched to $(_get_name "$TARGET")"
    exit 0
  '';
in
{
  imports = [ ./hardware-configuration.nix ];

  # ==========================================
  # KERNEL & BOOT
  # ==========================================
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [ "amd_pstate=active" "amdgpu.ppfeaturemask=0xffffffff" "quiet" "splash" ];
  boot.plymouth.enable = true;

  # Enabling Flakes natively
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  # ==========================================
  # NETWORKING & SECURITY
  # ==========================================
  networking.hostName = "nyx";
  networking.networkmanager.enable = true;
  networking.enableIPv6 = false;

  # Custom Mac Address
  # networking.interfaces.wlp1s0.useDHCP = true;
  # networking.interfaces.wlp1s0.macAddress = "11:22:33:44:55:66";
  networking.interfaces.enp1s0.macAddress = "11:22:33:33:22:11";

  networking.firewall = {
    enable = true;
    allowPing = true;
    logRefusedConnections = true;
  };

  boot.kernel.sysctl = {
    # Responsiveness Tweak
    "vm.dirty_ratio" = 10;

    # Hardening
    "kernel.kptr_restrict" = 2;
    "fs.protected_hardlinks" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "net.ipv6.conf.all.disable_ipv6" = 1;
  };

  # ==========================================
  # HARDWARE & BLUETOOTH
  # ==========================================

  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  # Bluetooth (Custom Minimal Build)
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez.overrideAttrs (oldAttrs: {
      configureFlags = (oldAttrs.configureFlags or []) ++ [
        "--disable-cups"
        "--disable-mesh"
        "--disable-obex"
        "--disable-hid2hci"
        "--disable-deprecated"
      ];
    });
    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
    };
  };

  # ==========================================
  # SERVICE OPTIMIZATIONS (PHASE 2)
  # ==========================================
  # Optimized service configurations
  services = {
    # Gaming Mouse - keep enabled
    ratbagd.enable = true;

    # Power management - optimized
    power-profiles-daemon = {
      enable = true;
      defaultProfile = "performance";
      # Reduce logging verbosity
      extraConfig = ''
        [log]
        level = warning
      '';
    };

    # UPower - optimized
    upower = {
      enable = true;
      criticalPowerAction = "HybridSleep";
      usePercentageForPolicy = true;
      percentageLow = 20;
      percentageCritical = 5;
      percentageAction = 3;
    };

    # Thunar/GNOME integration - optimized
    gvfs.enable = true;
    tumbler.enable = true;

    # GNOME services - optimized
    gnome = {
      evolution-data-server = {
        enable = true;
        # Reduce memory usage
        extraConfig = ''
          [Memory]
          CacheSize = 50
        '';
      };
      gnome-keyring = {
        enable = true;
        # Optimize keyring performance
        extraConfig = ''
          [daemon]
          login-timeout = 300
        '';
      };
    };
  };

  # PAM configuration for GNOME keyring
  security.pam.services.login.enableGnomeKeyring = true;

  # ==========================================
  # DISPLAY & GRAPHICS
  # ==========================================
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Pure Wayland
  services.xserver.enable = false;

  # Niri System Module
  programs.niri.enable = true;

  # Graphics Drivers & ROCm
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      amdvlk
      rocmPackages.clr
      rocmPackages.rocm-runtime
    ];
  };

  systemd.tmpfiles.rules = [
    "L+    /opt/rocm/hip   -    -    -     -    ${pkgs.rocmPackages.clr}"
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  # ==========================================
  # AUDIO
  # ==========================================
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # ==========================================
  # USERS & SHELLS
  # ==========================================
  users.users.ashy = {
    isNormalUser = true;
    description = "Ashy";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "render" ];
    shell = pkgs.fish;
    createHome = true;
    initialPassword = "icecream";
  };

  # SYSTEM PACKAGES
  # ==========================================
  environment.systemPackages = with pkgs; [
=======
  programs.fish.enable = true;
  programs.bash.enable = true;

  # ==========================================
  # BTRFS OPTIMIZATIONS
  # ==========================================
  # Since you're using Btrfs, let's optimize it
  environment.etc."btrfs-maintenance.xml".text = ''
    <?xml version="1.0"?>
    <config>
      <periodic>
        <balance enabled="true" interval="monthly"/>
        <scrub enabled="true" interval="weekly" priority="nice"/>
        <trim enabled="true" interval="daily" priority="nice"/>
        <defrag enabled="false"/>
      </periodic>
    </config>
  '';

  # Btrfs system packages
  environment.systemPackages = with pkgs; [
    btrfs-progs
    btrbk
    snapper
  ];

  # ==========================================
  # SYSTEM PACKAGES
  # ==========================================
  environment.systemPackages = with pkgs; [==========================================
  # SYSTEM PACKAGES
  # ==========================================
  environment.systemPackages = with pkgs; [
    # Custom Scripts
    g502Manager
    aichatSwap

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
    rocmPackages.rocm-smi rocmPackages.rocminfo

    # Terminal
    eza lsd bat fzf zoxide starship ripgrep fd jq age gum glow trash-cli
    fastfetch macchina btop nvtopPackages.amd

    # Gaming
    dualsensectl libratbag ratbagd mangohud latencyflex-vulkan

    # Theming / Fonts
    bibata-cursors
    (pkgs.catppuccin-sddm.override { flavor = "mocha"; })
    (nerdfonts.override { fonts = [
      "FiraCode" "Hack" "JetBrainsMono" "Meslo"
      "CascadiaCode" "Hermit" "Inconsolata" "Terminus"
    ]; })
    noto-fonts-cjk-sans noto-fonts-emoji
  ];

  # ==========================================
  # POWER MANAGEMENT & PERFORMANCE
  # ==========================================
  powerManagement = {
    cpuFreqGovernor = "performance";
    enable = true;
  };

  # Performance monitoring tools
  environment.systemPackages = with pkgs; [
    sysstat
    iotop
    iftop
    nmon
    bpytop
    powertop
  ];

  services.udev.packages = [ pkgs.game-devices-udev-rules ];
  system.stateVersion = "25.11";
}
