{ config, pkgs, lib, ... }:

let
  # --- 1. G502 MANAGER SCRIPT ---
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

  # Services
  services.ratbagd.enable = true; # Gaming Mouse
  services.power-profiles-daemon.enable = true; # Noctalia Req
  services.upower.enable = true; # Noctalia Req

  # Thunar/GNOME integration
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  services.gnome.evolution-data-server.enable = true; # Calendar events
  services.gnome.gnome-keyring.enable = true; # Secrets

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

  programs.fish.enable = true;
  programs.bash.enable = true;

  # ==========================================
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

  services.udev.packages = [ pkgs.game-devices-udev-rules ];
  system.stateVersion = "25.11";
}
