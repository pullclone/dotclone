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
    default = true;
    description = "Enable ProtonVPN GUI (Home Manager).";
  };

  options.my.identity.ssh.identity = mkOption {
    type = types.enum [
      "file"
      "fido2"
    ];
    default = "file";
    description = "SSH identity mode for the user (file-based keys or FIDO2-backed keys).";
  };

  options.my.identity.trezorAgent.enable = mkOption {
    type = types.bool;
    default = false;
    description = "Enable trezor-agent (optional SSH agent and Git signing integration).";
  };
}
