{ config, pkgs, lib, stylix, inputs, ... }:

let
  latencyflex = pkgs.callPackage ./latencyflex.nix { };
in
{
  imports = [ ./hardware-configuration.nix ];

  # Kernel and boot settings
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelParams = [
    "amd_pstate=active"
    "amdgpu.ppfeaturemask=0xffffffff"
    "quiet"
    "splash"
  ];

  boot.plymouth.enable = true;

  # Enable experimental features for Nix
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
      "ca-derivations"
    ];
    auto-optimise-store = true;
  };

  # Advanced Service Management
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

  # Journal optimizations
  services.journald.extraConfig = ''
    Compress=yes
    SystemMaxFileSize=50M
    RateLimitIntervalSec=30s
    RateLimitBurst=1000
  '';

  # Advanced Memory & Kernel Tuning
  boot.kernel.sysctl = {
    # Memory management
    "kernel.shmmni" = 4096;
    "vm.nr_hugepages" = 128;
    "vm.hugetlb_shm_group" = 0;
    "vm.overcommit_memory" = 1;
    "vm.overcommit_ratio" = 50;
    "vm.zone_reclaim_mode" = 0;
    "vm.dirty_background_bytes" = "16777216";
    "vm.dirty_bytes" = "67108864";
    "vm.dirty_ratio" = 10;
    "vm.max_map_count" = 262144;
    "vm.mmap_rnd_bits" = 32;

    # Security and hardening
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 0;
    "kernel.perf_event_paranoid" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;

    # Scheduler and network behaviour
    "kernel.sched_min_granularity_ns" = 10000000;
    "kernel.sched_wakeup_granularity_ns" = 15000000;
    "kernel.sched_latency_ns" = 60000000;
    "net.core.default_qdisc" = "fq";
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.ipv4.tcp_notsent_lowat" = 1;
    "net.ipv4.tcp_no_metrics_save" = 1;
    "net.ipv4.tcp_keepalive_time" = 300;
    "net.ipv4.tcp_keepalive_probes" = 5;
    "net.ipv4.tcp_keepalive_intvl" = 30;
    "net.ipv6.conf.all.disable_ipv6" = 1;
  };

  # I/O Scheduler Optimization
  boot.extraModprobeConfig = ''
    options elevator=bfq
    options scsi_mod.use_blk_mq=1
    options nvme_core.io_timeout=30
    options nvme_core.max_retries=1
  '';

  nixpkgs.config.allowUnfree = true;

  # Advanced Network Configuration
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

  # Advanced Power Management
  powerManagement = {
    cpuFreqGovernor = "performance";
    enable = true;
  };

  # Advanced Filesystem Optimization
  fileSystems."/" = {
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

  # Advanced Monitoring Configuration
  services = {
    netdata = {
      enable = true;
    };

    prometheus = {
      exporters.node = {
        enable = true;
        port = 9100;
        enabledCollectors = [ "systemd" "btrfs" "textfile" ];
        extraFlags = [
          "--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|run)$"
        ];
        openFirewall = false;
      };
    };

    grafana = {
      enable = true;
      settings.server.http_port = 3000;
    };
  };

  # Advanced Service Optimization
  systemd.services = {
    "optimize-services" = {
      description = "Service Optimization Timer";
      wantedBy = [ "timers.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          echo "Optimizing services..."
        '';
      };
    };

    "btrfs-optimize" = {
      description = "Btrfs Optimization Service";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = ''
          ${pkgs.btrfs-progs}/bin/btrfs filesystem defrag -r -v /
        '';
      };
    };
  };

  # Btrfs Optimization
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

  # Networking & Security
  networking.hostName = "nyx";
  networking.networkmanager.enable = true;
  networking.enableIPv6 = false;
  networking.interfaces.enp1s0.macAddress = "11:22:33:33:22:11";

  networking.firewall = {
    enable = true;
    allowPing = true;
    logRefusedConnections = true;
  };

  # Hardware & Bluetooth
  hardware.enableRedistributableFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

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

      # If you ever hit flaky unit tests again, keep these:
      doCheck = false;
      doInstallCheck = false;

      # Key bit: avoid Nix failing noBrokenSymlinks when OBEX is disabled
      postFixup = (old.postFixup or "") + ''
        if [ -L "$out/bin/obexd" ] && [ ! -e "$out/bin/obexd" ]; then
          echo "Removing dangling symlink: $out/bin/obexd"
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
  
  # Service Optimizations
  services = {
    ratbagd.enable = true;

    power-profiles-daemon = {
      enable = true;
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

    gnome = {
      evolution-data-server = {
        enable = true;
      };
      gnome-keyring = {
        enable = true;
      };
    };
  };

  security.pam.services.login.enableGnomeKeyring = true;

  # Kernel & Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Display & Graphics
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  services.xserver.enable = false;

  programs.niri.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr
      rocmPackages.rocm-runtime
      latencyflex
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

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # Users & Shells
  users.users.ashy = {
    isNormalUser = true;
    description = "Ashy";
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" "render" ];
    shell = pkgs.fish;
    createHome = true;
    initialPassword = "icecream";
  };

  # System packages
  environment.systemPackages = with pkgs;
    [
      btrfs-progs btrbk snapper
      git curl wget micro
      unzip unrar p7zip
      libnotify wl-clipboard cliphist
      grim slurp
      udiskie
      xfce.thunar xfce.thunar-volman mate.engrampa
      brave firefox
      pwvucontrol pavucontrol playerctl ffmpeg mpv
      gst_all_1.gstreamer gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good gst_all_1.gst-plugins-bad
      gst_all_1.gst-plugins-ugly gst_all_1.gst-libav
      (python311.withPackages (ps: with ps; [ pygobject3 numpy pandas ]))
      rocmPackages.rocm-smi rocmPackages.rocminfo
      eza lsd bat fzf zoxide starship ripgrep fd jq age gum glow rucola trash-cli
      fastfetch macchina btop nvtopPackages.amd
      dualsensectl libratbag mangohud
      latencyflex
      bibata-cursors
      (pkgs.catppuccin-sddm.override { flavor = "mocha"; })
      pkgs.nerd-fonts.fira-code
      pkgs.nerd-fonts.hack
      pkgs.nerd-fonts.jetbrains-mono
      pkgs.nerd-fonts.meslo-lg
      noto-fonts-cjk-sans noto-fonts-color-emoji
      util-linux
      procps
      iputils
      iproute2
      mkpasswd
      stress-ng
      iperf3
      sysstat
      iotop
      iftop
      nmon
      powertop
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

  # Shells
  programs.fish.enable = true;
  programs.bash.enable = true;

  # Timezone configuration
  time.timeZone = "UTC";

  system.stateVersion = "25.11";
}
