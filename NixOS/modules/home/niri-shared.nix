{ config, pkgs, ... }:

{
  programs.niri.settings = {
    # --- 1. Environment & Startup ---
    environment = {
      SSH_AUTH_SOCK = "/run/user/1000/keyring/ssh";
      XDG_CURRENT_DESKTOP = "niri";
      QS_ICON_THEME = "Papirus-Dark";
    };

    spawn-at-startup = [
      { command = [ "${pkgs.polkit_gnome}/bin/polkit-gnome-authentication-agent-1" ]; }
      { command = [ "g502-manager" "setup" ]; }
      { command = [ "xwayland-satellite" ]; }
      { command = [ "wl-paste" "--type" "text" "--watch" "cliphist" "store" ]; }
    ];

    # --- 2. Input & Layout ---
    input = {
      keyboard.xkb.layout = "us"; # Or "br" if that was your pref
      touchpad = { tap = true; natural-scroll = true; };
      mouse.enable = true;
    };

    layout = {
      gaps = 8;
      center-focused-column = "never";
      focus-ring.enable = false;
      border = {
        enable = true;
        width = 2;
        active.color = "#c678dd";
        inactive.color = "#505050";
      };

      # Dwindle-like Preset Widths
      preset-column-widths = [
        { proportion = 0.33333; }
        { proportion = 0.5; }
        { proportion = 0.66667; }
      ];
      default-column-width = { proportion = 0.5; };
    };

    # --- 3. CORE BINDS (Shared) ---
    binds = with config.lib.niri.actions; {
      "Mod+Shift+Slash".action = show-hotkey-overlay;
      "Mod+L".action = spawn "swaylock";

      # Apps (Terminal/Files determined by system defaults)
      "Mod+Return".action = spawn "kitty";
      "Mod+T".action = spawn "kitty";
      "Mod+E".action = spawn "thunar";
      "Mod+B".action = spawn "brave";

      # Window Management
      "Mod+Q".action = close-window;
      "Mod+Shift+Q".action = quit;
      "Mod+F".action = maximize-column;
      "Mod+Shift+F".action = fullscreen-window;
      "Mod+Z".action = toggle-window-floating;
      "Mod+O".action = toggle-overview;

      # Focus Navigation (Vim + Arrows)
      "Mod+Left".action = focus-column-left;
      "Mod+Right".action = focus-column-right;
      "Mod+Down".action = focus-window-down;
      "Mod+Up".action = focus-window-up;
      "Mod+H".action = focus-column-left;
      "Mod+L".action = focus-column-right;
      "Mod+J".action = focus-window-down;
      "Mod+K".action = focus-window-up;

      # Moving Windows
      "Mod+Shift+Left".action = move-column-left;
      "Mod+Shift+Right".action = move-column-right;
      "Mod+Shift+Down".action = move-window-down;
      "Mod+Shift+Up".action = move-window-up;
      "Mod+Ctrl+Left".action = move-column-left;
      "Mod+Ctrl+Right".action = move-column-right;

      # Workspaces 1-9
      "Mod+1".action.focus-workspace = 1;
      "Mod+2".action.focus-workspace = 2;
      "Mod+3".action.focus-workspace = 3;
      "Mod+4".action.focus-workspace = 4;
      "Mod+5".action.focus-workspace = 5;
      "Mod+6".action.focus-workspace = 6;
      "Mod+7".action.focus-workspace = 7;
      "Mod+8".action.focus-workspace = 8;
      "Mod+9".action.focus-workspace = 9;

      "Mod+Shift+1".action.move-column-to-workspace = 1;
      "Mod+Shift+2".action.move-column-to-workspace = 2;
      "Mod+Shift+3".action.move-column-to-workspace = 3;
      "Mod+Shift+4".action.move-column-to-workspace = 4;
      "Mod+Shift+5".action.move-column-to-workspace = 5;

      # Mouse & Audio
      "XF86AudioRaiseVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05+";
      "XF86AudioLowerVolume".action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.05-";
      "XF86AudioMute".action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
      "XF86AudioMicMute".action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle";

      # G502 Integration (Global script)
      "F23".action = spawn "g502-manager" "prev";
      "F24".action = spawn "g502-manager" "next";
    };

    # --- 4. Window Rules (Shared) ---
    window-rules = [
      {
        matches = [ { is-floating = true; } ];
        shadow.enable = true;
        border.enable = true;
      }
      {
        matches = [ { app-id = "pavucontrol"; } ];
        open-floating = true;
      }
      {
        matches = [ { title = "Picture-in-Picture"; } ];
        open-floating = true;
        default-column-width = { fixed = 480; };
      }
    ];
  };
}
