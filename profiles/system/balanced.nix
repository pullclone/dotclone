{ lib, config, pkgs, inputs, ... }:

{
  imports = [
    inputs.profiles.nyxProfiles.zram.zstd-balanced
  ];

  boot.kernel.sysctl = {
    "vm.page-cluster" = 0;
    "vm.swappiness" = 100;
    "vm.vfs_cache_pressure" = 50;

    "vm.dirty_background_ratio" = 10;
    "vm.dirty_ratio" = 20;
    "vm.dirty_writeback_centisecs" = 200;
    "vm.dirty_expire_centisecs" = 1500;
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
}
