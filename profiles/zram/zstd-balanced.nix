{
  config,
  pkgs,
  lib,
  ...
}:

{
  zramSwap = {
    enable = true;
    algorithm = "zstd";

    # 50% is the standard "safe" default.
    # On 32GB RAM, this gives you ~16GB compressed swap.
    memoryPercent = lib.mkDefault 50;

    # Keep zram preferred over any disk swap if present.
    priority = lib.mkDefault 100;
  };

  boot.kernel.sysctl = {
    # 120 is a nice middle ground.
    "vm.swappiness" = lib.mkDefault 120;

    # Helps reduce direct-reclaim stalls under pressure.
    "vm.watermark_scale_factor" = lib.mkDefault 125;

    # Lower latency under reclaim; 0 is usually best with zram.
    "vm.page-cluster" = lib.mkDefault 0;
  };
}
