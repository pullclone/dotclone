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

    # Encourage reclaim, reduce background activity
    "vm.swappiness" = 80;
    "vm.vfs_cache_pressure" = 75;

    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 15;
    "vm.dirty_writeback_centisecs" = 500;
    "vm.dirty_expire_centisecs" = 3000;
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";
}
