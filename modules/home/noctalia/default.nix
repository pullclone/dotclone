{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  cfg = config.my.desktop;
  noctaliaPkg = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Helper for cleaner Noctalia calls
  noctalia = cmd: {
    action = config.lib.niri.actions.spawn (
      [
        "noctalia-shell"
        "ipc"
        "call"
      ]
      ++ (pkgs.lib.splitString " " cmd)
    );
  };

  # Minimal Catppuccin Mocha palette (avoids Stylix dependency when disabled)
  palette = {
    base00 = "181825";
    base01 = "1e1e2e";
    base02 = "313244";
    base03 = "45475a";
    base05 = "cdd6f4";
    base08 = "f38ba8";
    base0A = "f9e2af";
    base0B = "a6e3a1";
    base0D = "89b4fa";
  };
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  config = lib.mkIf (cfg.panel == "noctalia") {

    # 1. Set the shell variable for this profile
    home.sessionVariables = {
      LAUNCHER_CMD = "fuzzel -d";
    };

    # 2. Install packages ONLY for the Noctalia profile
    home.packages = with pkgs; [
      fuzzel
      papirus-nord
      pwvucontrol
      brightnessctl
    ];

    # 3. Configure Noctalia itself
    programs.noctalia-shell = with palette; {
      enable = true;
      systemd.enable = true; # Use the Home Manager service
      package = noctaliaPkg;

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
              {
                id = "Clock";
                formatHorizontal = "HH:mm";
              }
              {
                id = "SystemMonitor";
                showCpuUsage = true;
              }
            ];
            center = [
              {
                id = "Workspace";
                labelMode = "none";
              }
            ];
            right = [
              { id = "Tray"; }
              { id = "Battery"; }
              {
                id = "ControlCenter";
                icon = "cat";
              }
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

    systemd.user.services.noctalia-lock = {
      Unit = {
        Description = "Noctalia lock (lock.target)";
      };
      Service = {
        ExecStart = "${noctaliaPkg}/bin/noctalia-shell ipc call lock";
      };
      Install = {
        WantedBy = [ "lock.target" ];
      };
    };

  };
}
