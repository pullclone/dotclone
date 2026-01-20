{ lib, ... }:
let
  inherit (lib) mkOption types mkEnableOption;
in
{
  options.my.desktop = {
    enable = mkEnableOption "Enable custom desktop";

    panel = mkOption {
      type = types.enum [
        "noctalia"
        "waybar"
      ];
      default = "noctalia";
      description = "Choose the panel/bar interface.";
    };

    terminal = mkOption {
      type = types.enum [
        "kitty"
        "alacritty"
      ];
      default = "kitty";
    };
  };

  options.my.home.apps.protonvpn.enable = mkOption {
    type = types.bool;
    default = false;
    description = "Enable ProtonVPN GUI (Home Manager).";
  };

  options.my.identity.trezorAgent.enable = mkOption {
    type = types.bool;
    default = false;
    description = "Enable trezor-agent (SSH agent and optional Git signing).";
  };
}
