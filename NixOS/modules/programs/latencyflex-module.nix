{ config, lib, pkgs, ... }:

let
  cfg = config.my.performance.latencyflex;
in
{
  options.my.performance.latencyflex = {
    enable = lib.mkEnableOption "Enable LatencyFleX Vulkan implicit layer";
  };

  config = lib.mkIf cfg.enable {
    # We moved the package definition to pkgs/latencyflex.nix in the root.
    # From modules/programs/latencyflex-module.nix, that is ../../pkgs/latencyflex.nix
    environment.systemPackages = [
      (pkgs.callPackage ../../pkgs/latencyflex.nix { })
    ];
  };
}
