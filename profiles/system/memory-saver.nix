{ lib, config, pkgs, inputs, ... }:

{
  imports = [
    inputs.profiles.nyxProfiles.zram.zstd-aggressive
  ];

  boot.kernel.sysctl = {
    "vm.page-cluster" = 0;

    # Be willing to swap compressed pages to fit more apps
    "vm.swappiness" = 150;
    "vm.vfs_cache_pressure" = 75;

    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 10;
    "vm.dirty_writeback_centisecs" = 200;
    "vm.dirty_expire_centisecs" = 1500;
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
}
