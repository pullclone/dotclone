{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.my.desktop;

  # --- 1. Wallpaper Cycler (Uses swww) ---
  cycleWall = pkgs.writeShellScriptBin "waybar-cycle-wall" ''
    #!/usr/bin/env bash
    # Define your wallpaper directory
    WALL_DIR="${config.home.homeDirectory}/nixdots/assets/wallpapers"

    if [ ! -d "$WALL_DIR" ]; then
      ${pkgs.libnotify}/bin/notify-send "Error" "Wallpaper directory not found at $WALL_DIR"
      exit 1
    fi

    # Get random wallpaper
    PICS=("$WALL_DIR"/*)
    RANDOM_PIC="''${PICS[RANDOM % ''${#PICS[@]}]}"

    # Transition
    ${pkgs.swww}/bin/swww img "$RANDOM_PIC" --transition-type grow --transition-pos 0.925,0.977 --transition-step 90 --transition-duration 2

    # Send notification
    ${pkgs.libnotify}/bin/notify-send "Wallpaper" "Changed to $(basename "$RANDOM_PIC")"
  '';

  # --- 2. Screenshot Tool (Uses grim + slurp) ---
  screenshotTool = pkgs.writeShellScriptBin "waybar-screenshot" ''
    #!/usr/bin/env bash
    DIR="${config.home.homeDirectory}/Pictures/Screenshots"
    mkdir -p "$DIR"
    NAME="Screenshot_$(date +%Y%m%d_%H%M%S).png"

    case "$1" in
        "full")
            ${pkgs.grim}/bin/grim "$DIR/$NAME"
            ${pkgs.libnotify}/bin/notify-send "Screenshot" "Fullscreen saved to $DIR"
            ;;
        "area")
            ${pkgs.grim}/bin/grim -g "$(${pkgs.slurp}/bin/slurp)" "$DIR/$NAME"
            ${pkgs.libnotify}/bin/notify-send "Screenshot" "Area saved to $DIR"
            ;;
        *)
            echo "Usage: waybar-screenshot [full|area]"
            exit 1
            ;;
    esac
    # Copy to clipboard as well
    ${pkgs.wl-clipboard}/bin/wl-copy < "$DIR/$NAME"
  '';

  # --- 3. Power Menu / Lock (Wofi wrapper) ---
  powerMenu = pkgs.writeShellScriptBin "waybar-power" ''
    #!/usr/bin/env bash
    # A simple wofi menu for power ops
    op=$(echo -e " Poweroff\n Reboot\n Suspend\n Lock\n Logout" | ${pkgs.wofi}/bin/wofi --dmenu --prompt "Power Menu" --width 200 --height 250)

    case $op in
        " Poweroff") systemctl poweroff ;;
        " Reboot") systemctl reboot ;;
        " Suspend") systemctl suspend ;;
        " Lock") ${pkgs.swaylock-effects}/bin/swaylock ;;
        " Logout") niri msg action quit ;;
    esac
  '';

in
{
  # Only install these scripts if Waybar is active
  config = lib.mkIf (cfg.panel == "waybar") {
    home.packages = [
      cycleWall
      screenshotTool
      powerMenu
    ];
  };
}
