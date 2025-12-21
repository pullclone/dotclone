nix
{ config, pkgs, ... }:

{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    # 100% means we create a swap device equal to your physical RAM size.
    # Because zstd compresses ~3:1, this is safe-ish.
    memoryPercent = 100;
    priority = 100;
  };

  boot.kernel.sysctl = {
    # Max swappiness (200 on modern kernels, 100 on older).
    # Force the kernel to shove everything cold into ZRAM immediately.
    "vm.swappiness" = 180;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };
}
