{ config, pkgs, lib, ... }:
{
  zramSwap = {
    enable = true;
    algorithm = "lz4";

    # 10GB is roughly 30% of 32GB, or you can set explicit priority
    memoryPercent = lib.mkDefault 30;
    priority = lib.mkDefault 100;
  };

  boot.kernel.sysctl = {
    # Aggressively use ZRAM
    "vm.swappiness" = lib.mkDefault 80;

    # Helps with latency under load
    "vm.watermark_scale_factor" = lib.mkDefault 125;

    # better for lz4/zram latency
    "vm.page-cluster" = lib.mkDefault 0;
  };
}
