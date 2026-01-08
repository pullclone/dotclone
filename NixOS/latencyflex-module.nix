{ lib, pkgs, config, ... }:
let cfg = config.my.performance.latencyflex;
in {
  options.my.performance.latencyflex.enable =
    lib.mkEnableOption "LatencyFleX Vulkan layer";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.latencyflex ];
  };
}
