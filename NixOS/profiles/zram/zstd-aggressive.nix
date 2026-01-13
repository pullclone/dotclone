{ config, pkgs, lib, ... }:

{
  zramSwap = {
    enable = true;
    algorithm = "zstd";

    # aggressive but safe on 32GB+
    memoryPercent = lib.mkDefault 100;
    priority = lib.mkDefault 100;
  };

  boot.kernel.sysctl = {
    # Aggressive maximize effective headroom, accept CPU cost
    "vm.swappiness" = lib.mkDefault 180;
    "vm.watermark_scale_factor" = lib.mkDefault 125;
    "vm.page-cluster" = lib.mkDefault 0;
  };
}
