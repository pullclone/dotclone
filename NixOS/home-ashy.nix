{ config, pkgs, lib, ... }:

{
  home.stateVersion = "25.11";
  home.username = "ashy";
  home.homeDirectory = "/home/ashy";

  imports = [
    # --- 1. CORE DEFINITIONS ---
    ./modules/home/options.nix
    ./modules/home/shells.nix
    ./modules/home/niri-shared.nix

    # --- 2. GLOBAL APPS & TERMINALS ---
    ./modules/home/apps/brave-webapps.nix
    ./modules/home/apps/btop.nix
    ./modules/home/apps/cava.nix
    ./modules/home/terminals/kitty.nix

    # --- 3. PANELS (Gated internally via mkIf) ---
    ./modules/noctalia/default.nix
    ./modules/waybar/default.nix
  ];

  # --- CONFIGURATION TOGGLES ---
  my.desktop = {
    enable = true;
    panel = "noctalia";   # Change to "waybar" to switch
    terminal = "kitty";
  };

  programs.home-manager.enable = true;

  # --- SHARED PACKAGES ---
  # Only packages that must exist regardless of profile
  home.packages = with pkgs; [
    # Core
    kitty alacritty
    niri
    thunar

    # Notifications/Wallpaper (Shared backend)
    swww
    mako

    # AI
    aichat

    # Btrfs management tools
    btrfs-progs
    btrbk  # Btrfs backup tool
    snapper # Btrfs snapshot management

    # Performance monitoring tools
    sysstat
    iotop
    iftop
    nmon
    bpytop
    powertop
  ];
}
