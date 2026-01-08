{ config, lib, pkgs, ... }:

let
  cfg = config.my.performance.latencyflex;
in
{
  options.my.performance.latencyflex = {
    enable = lib.mkEnableOption "Enable LatencyFleX Vulkan implicit layer";
  };

  config = lib.mkIf cfg.enable {
    # If you already package it in an overlay or pkgs set, use that.
    # Otherwise, import the derivation directly from the repo.
    environment.systemPackages = [
      (pkgs.callPackage ../latencyflex.nix { })
    ];
  };
}
