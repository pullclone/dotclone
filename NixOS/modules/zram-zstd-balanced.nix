{ config, pkgs, ... }:

{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    # 50% is the standard "safe" default.
    # On 32GB RAM, this gives you ~16GB compressed swap.
    memoryPercent = 50;
    priority = 100;
  };

  boot.kernel.sysctl = {
    # 150 is a sweet spot for zstd. It prefers swapping to ZRAM
    # slightly more than lz4 configs, because the space savings are worth it.
    "vm.swappiness" = 150;
    "vm.watermark_scale_factor" = 125;
    # Page-cluster 0 is CRITICAL for zstd to avoid latency spikes
    "vm.page-cluster" = 0;
  };
}
