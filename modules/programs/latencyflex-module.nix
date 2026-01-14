# modules/latencyflex-module.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.my.performance.latencyflex;
in
{
  options.my.performance.latencyflex.enable =
    lib.mkEnableOption "Enable LatencyFleX Vulkan implicit layer";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.latencyflex ];

    # Important: makes /run/current-system/sw/share/vulkan populated
    # so Vulkan loader can discover implicit layers
    environment.pathsToLink = [ "/share/vulkan" ];
  };
}
