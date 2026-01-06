{ config, pkgs, ... }:
{
  zramSwap = {
    enable = true;
    algorithm = "lz4";
    # 10GB is roughly 30% of 32GB, or you can set explicit priority
    memoryPercent = 35;
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 100; # Aggressively use ZRAM
    "vm.watermark_scale_factor" = 125; # Helps with latency under load
    "vm.page-cluster" = 0; # better for lz4/zram latency
  };
}
