{ config, pkgs, lib, stylix, inputs, ... }:

let
  latencyflex = pkgs.callPackage ./pkgs/latencyflex.nix { };
in

{
  imports = [ ./hardware-configuration.nix ];

  # ==========================================
  # CORE SYSTEM
  # ==========================================
  system.stateVersion = "25.11";
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [ "ventoy-gtk3-1.1.07" ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "ca-derivations"
    ];
    auto-optimise-store = true;
  };

  # Kernel modules
  boot.kernelModules = [ "i2c-dev" "spi-dev" ];

  # NOTE: Bootloader, Kernel Params, and Microcode are now handled
  # by modules/boot-profile.nix and modules/hardware/amd-gpu.nix

  # ==========================================
  # SWAP & STORAGE
  # ==========================================
  # Randomly encrypted swap (Ephemeral, key regenerated at boot)
  swapDevices = [
    {
      device = "/dev/disk/by-partlabel/SWAP";
      randomEncryption.enable = true;
      priority = 10; # Lower priority than ZRAM (100)
    }
  ];

  # ==========================================
  # SERVICES
  # ==========================================
  systemd = {
    services = {
      sddm = {
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" "dbus.service" ];
      };
      NetworkManager = {
        wantedBy = [ "multi-user.target" ];
        after = [ "dbus.service" ];
      };
    };
  };

  # Service Optimization Timer
  systemd.services."optimize-services" = {
    description = "Service Optimization Timer";
    wantedBy = [ "timers.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = ''
        echo "Optimizing services..."
      '';
    };
  };

  # Journal optimizations
  services.journald.extraConfig = ''
    Compress=yes
    SystemMaxFileSize=50M
    RateLimitIntervalSec=30s
    RateLimitBurst=1000
  '';

  # ==========================================
  # NETWORKING
  # ==========================================
  # Hostname/Timezone/MAC handled by modules/install-answers.nix
  networking = {
    nameservers = [
      "142.242.2.2"      # Mullvad
      "94.140.14.14"     # AdGuard
      "94.140.15.15"     # AdGuard
      "149.112.112.112"  # Quad9
      "9.9.9.9"          # Quad9
      "1.1.1.2"          # Cloudflare
      "1.0.0.2"          # Cloudflare
      "1.1.1.1"          # Cloudflare
      "1.0.0.1"          # Cloudflare
    ];
    useDHCP = false;
  };

  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  networking.enableIPv6 = false;

  networking.firewall = {
    enable = true;
    allowPing = true;
    logRefusedConnections = true;
  };

  # ==========================================
  # POWER & HARDWARE
  # ==========================================
  powerManagement = {
    cpuFreqGovernor = "performance";
    enable = true;
  };

  hardware.enableRedistributableFirmware = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;

    package = pkgs.bluez.overrideAttrs (old: {
      configureFlags = (old.configureFlags or []) ++ [
        "--disable-cups"
        "--disable-mesh"
        "--disable-obex"
        "--disable-hid2hci"
      ];
      doCheck = false;
      doInstallCheck = false;
      postFixup = (old.postFixup or "") + ''
        if [ -L "$out/bin/obexd" ] && [ ! -e "$out/bin/obexd" ]; then
          rm -f "$out/bin/obexd"
        fi
      '';
    });

    settings = {
      General = {
        Experimental = true;
        FastConnectable = true;
      };
    };
  };

  # ==========================================
  # DESKTOP SERVICES
  # ==========================================
  services = {
    # Input & Power
    ratbagd.enable = true;
    power-profiles-daemon.enable = true;
    upower = {
      enable = true;
      criticalPowerAction = "HybridSleep";
      usePercentageForPolicy = true;
      percentageLow = 20;
      percentageCritical = 5;
      percentageAction = 3;
    };

    # Gnome Integration
    gvfs.enable = true;
    tumbler.enable = true;
    gnome = {
      evolution-data-server.enable = true;
      gnome-keyring.enable = true;
    };

    # Display
    displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
    xserver.enable = false;

    # Audio
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # Storage / devices
    udisks2.enable = true;

    # Monitoring Stack
    netdata.enable = true;
    grafana = {
      enable = true;
      settings.server.http_port = 3000;
    };
    prometheus.exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [ "systemd" "btrfs" "textfile" ];
      extraFlags = [
        "--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|run)$"
      ];
      openFirewall = false;
    };
  };

  # RNG daemon (rngd removed upstream; jitterentropy provides the service)
  services.jitterentropy-rngd.enable = true;

  security.pam.services.login.enableGnomeKeyring = true;

  # Niri & Portals
  programs.niri.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "gtk";
  };

  # Storage hygiene (TRIM) driven by install answers
  services.fstrim = {
    enable = config.my.install.storage.trim.enable;
    interval = config.my.install.storage.trim.interval;
  };

  # User-level udiskie session (no upstream module available)
  systemd.user.services.udiskie = {
    description = "udiskie automounter";
    wantedBy = [ "default.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.udiskie}/bin/udiskie --tray";
      Restart = "on-failure";
    };
  };

  # ==========================================
  # USERS
  # ==========================================
  users.mutableUsers = true;

  users.users."${config.my.install.userName}" = {
    isNormalUser = true;
    description = config.my.install.userName;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "render" ];
    shell = pkgs.fish;
    createHome = true;
    # No initialPassword. Set via 'passwd' on first boot.
  };

  programs.fish.enable = true;
  programs.bash.enable = true;

  # ==========================================
  # PACKAGES & SCRIPTS
  # ==========================================
  environment.systemPackages = with pkgs;
    [
      # Core Tools
      btrfs-progs btrbk
      git curl wget micro
      unzip unrar p7zip
      libnotify wl-clipboard cliphist
      grim slurp udiskie

      # File Management
      xfce.thunar xfce.thunar-volman mate.engrampa

      # Web & Media
      brave firefox
      pwvucontrol pavucontrol playerctl ffmpeg mpv
      gst_all_1.gstreamer gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly gst_all_1.gst-libav

      # Python / AI
      (python311.withPackages (ps: with ps; [ pygobject3 numpy pandas ]))

      # Terminal Enhancements
      eza lsd bat fzf zoxide starship ripgrep fd jq age gum glow rucola trash-cli
      fastfetch macchina btop

      # Gaming / Input
      dualsensectl libratbag mangohud latencyflex

      # Theming
      bibata-cursors
      (pkgs.catppuccin-sddm.override { flavor = "mocha"; })
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.hack
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.nerd-fonts.meslo-lg
      noto-fonts-cjk-sans noto-fonts-color-emoji

      # Sysadmin Utils
      util-linux procps iputils iproute2 mkpasswd
      stress-ng iperf3 sysstat iotop iftop nmon powertop

      # Security / crypto
      gnupg tpm2-tools tpm2-tss gopass pinentry-gnome3 gocryptfs

      # CLI / network / utils
      lla skim mtr rsync which whois

      # OCR
      tesseract5 tesseract5.languages.eng

      # Debug / monitoring
      strace lm_sensors linuxPackages.iio-utils evtest

      # Storage / disk tools
      hdparm nvme-cli smartmontools parted gptfdisk e2fsprogs dosfstools ntfs3g xz xfsprogs

      # Terminal / session tools
      screen minicom picocom tmux

      # Media / audio tools
      lame flac fdk_aac ffmpeg alsa-utils sox amberol abcde

      # PDF / poppler tools
      poppler poppler-utils

      # iOS device support
      libimobiledevice ifuse usbmuxd

      # Clipboard / Wayland
      wl-clipboard

      # Networking / analysis
      wireshark

      # Performance
      ananicy-rules-cachyos ananicy-cpp

      # Framework tooling
      framework-tool framework-tool-tui

      # Boot/install media + video tools
      ventoy-full-gtk shotcut handbrake

      # Auth / escalation
      shadow

      # Dev tooling
      rustup

      # GPIO / hardware tooling
      i2c-tools dtc sigrok-cli pulseview libgpiod

      # Python hardware libs
      python3Packages.smbus2 python3Packages.pyserial python3Packages.rpi-gpio

      # Qt theming
      libsForQt5.qt5ct

      # COSMIC apps and storage helpers
      cosmic-files cosmic-edit cosmic-player cosmic-term udisks2 udiskie

      # RNG tools
      rng-tools
    ]
    ++ [
      (writeShellScriptBin "g502-manager" ''
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
            if ${libratbag}/bin/ratbagctl "$MOUSE_NAME" profile active set "$profile" 2>/dev/null; then
                echo "$profile" > "$STATE_FILE"
                ${libnotify}/bin/notify-send "G502 Profile" "Switched to Profile $profile" -t 1000
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
                RATBAG="${libratbag}/bin/ratbagctl"

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
      '')
      (writeShellScriptBin "aichat-swap" ''
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
      '')
    ];

  fonts.packages = with pkgs; [
    maple-mono.truetype
    maple-mono.NF-unhinted
  ];

  security = {
    sudo.enable = false;
    doas = {
      enable = true;
      extraRules = [
        {
          users = [ "ashy" ];
          keepEnv = true;
          persist = true;
        }
      ];
    };
  };

}
