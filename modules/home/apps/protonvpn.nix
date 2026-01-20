{ config, pkgs, lib, ... }:

let
  cfg = config.my.home.apps.protonvpn;
in
{
  options.my.home.apps.protonvpn.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable ProtonVPN GUI via Home Manager.";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.protonvpn-gui ];
  };
}
