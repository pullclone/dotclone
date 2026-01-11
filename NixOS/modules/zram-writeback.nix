{ config, pkgs, ... }:

{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
    priority = 100;
    # REPLACE THIS with your actual empty swap partition
    # writebackDevice = "/dev/nvme0n1p3";
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 150;
    "vm.page-cluster" = 0;
  };
}
