{ config, pkgs, lib, pkgsUnstable, ... }:

let
  cfg = config.my.desktop;

  # Helper for cleaner Noctalia calls
  noctalia = cmd: {
    action = config.lib.niri.actions.spawn (
      [ "noctalia-shell" "ipc" "call" ] ++ (pkgs.lib.splitString " " cmd)
    );
  };
in
{
  config = lib.mkIf (cfg.panel == "noctalia") {

    # 1. Set the shell variable for this profile
    home.sessionVariables = { LAUNCHER_CMD = "fuzzel -d"; };

    # 2. Install packages ONLY for the Noctalia profile
    home.packages = with pkgs; [
      pkgsUnstable.noctalia-shell
      fuzzel
      papirus-nord
      pwvucontrol
      brightnessctl
    ];

    # 3. Configure Noctalia itself
    programs.noctalia-shell = with config.lib.stylix.colors; {
      enable = true;
      systemd.enable = true; # Use the Home Manager service

      # Theming logic (Merged from old ui.nix / stylix.nix)
      colors = {
        mPrimary = "#${base0B}";
        mOnPrimary = "#${base00}";
        mPrimaryContainer = "#${base0B}";
        mOnPrimaryContainer = "#${base00}";
        mSecondary = "#${base0A}";
        mOnSecondary = "#${base00}";
        mSecondaryContainer = "#${base0A}";
        mOnSecondaryContainer = "#${base00}";
        mTertiary = "#${base0D}";
        mOnTertiary = "#${base00}";
        mTertiaryContainer = "#${base0D}";
        mOnTertiaryContainer = "#${base00}";
        mError = "#${base08}";
        mOnError = "#${base00}";
        mErrorContainer = "#${base08}";
        mOnErrorContainer = "#${base00}";
        mBackground = "#${base00}";
        mOnBackground = "#${base05}";
        mSurface = "#${base01}";
        mOnSurface = "#${base05}";
        mSurfaceVariant = "#${base02}";
        mOnSurfaceVariant = "#${base05}";
        mOutline = "#${base03}";
        mOutlineVariant = "#${base02}";
        mShadow = "#000000";
        mScrim = "#000000";
        mInverseSurface = "#${base05}";
        mInverseOnSurface = "#${base00}";
        mInversePrimary = "#${base0B}";
        mHover = "#${base0D}";
        mOnHover = "#${base00}";
      };

      settings = {
        settingsVersion = 26;

        general = {
          avatarImage = "${config.home.homeDirectory}/.face";
          allowPanelsOnScreenWithoutBar = true;
          lockOnSuspend = true;
        };

        appLauncher = {
          terminalCommand = "kitty"; # Our override: use Kitty, not WezTerm
          viewMode = "grid";
          enableClipboardHistory = true;
        };

        bar = {
          position = "right";
          density = "comfortable";
          widgets = {
            left = [
              { id = "Clock"; formatHorizontal = "HH:mm"; }
              { id = "SystemMonitor"; showCpuUsage = true; }
            ];
            center = [ { id = "Workspace"; labelMode = "none"; } ];
            right = [
              { id = "Tray"; }
              { id = "Battery"; }
              { id = "ControlCenter"; icon = "cat"; }
            ];
          };
        };

        wallpaper = {
          enabled = true;
          directory = "${config.home.homeDirectory}/nixdots/assets/wallpapers";
          panelPosition = "follow_bar";
        };

        # Disable templates for things we manage via Nix
        templates = {
          gtk = false;
          qt = false;
          kitty = false;
          niri = false;
        };
      };
    };

    # 4. Stylix Overrides
    # We disable Niri theming here because Noctalia manages its own Niri integration
    # and we provide manual binds below.
    stylix = {
        targets.niri.enable = false;
    };

    # 5. Add Noctalia-specific keybinds to Niri
    # These are merged with the base keybinds from niri-shared.nix
    programs.niri.settings.binds = {
      "Mod+A" = noctalia "launcher toggle";
      "Mod+W" = noctalia "wallpaper toggle";
      "Mod+P" = noctalia "sessionMenu toggle";
      "Mod+V" = noctalia "launcher clipboard";
    };
  };
}
