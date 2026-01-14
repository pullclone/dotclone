{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.profiles.nyxProfiles.zram.zstd-balanced
  ];

  boot.kernel.sysctl = {
    "vm.page-cluster" = 0;

    # Less eager swapping; keep working sets warm
    "vm.swappiness" = 60;
    "vm.vfs_cache_pressure" = 40;

    # Favor throughput: allow larger dirty buffers
    "vm.dirty_background_ratio" = 15;
    "vm.dirty_ratio" = 30;
    "vm.dirty_writeback_centisecs" = 300;
    "vm.dirty_expire_centisecs" = 2000;
  };

  # Either works; start with schedutil unless you want max sustained clocks
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
}
