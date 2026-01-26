{ config, pkgs, lib, ... }:

let
  cfg = config.my.home.apps.protonvpn;
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.protonvpn-gui ];
  };
}
