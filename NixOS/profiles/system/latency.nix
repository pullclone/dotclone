{ lib, config, pkgs, inputs, ... }:

{
  imports = [
    inputs.profiles.nyxProfiles.zram.lz4
  ];

  # Latency-first VM behavior
  boot.kernel.sysctl = {
    "vm.page-cluster" = 0;
    "vm.swappiness" = 120;
    "vm.vfs_cache_pressure" = 50;

    # Reduce writeback stalls / UI hitching
    "vm.dirty_background_ratio" = 5;
    "vm.dirty_ratio" = 15;
    "vm.dirty_writeback_centisecs" = 100;
    "vm.dirty_expire_centisecs" = 1000;
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "performance";

  services.irqbalance.enable = lib.mkDefault true;

  # Optional (only if already validated on your hardware):
  # boot.kernelParams = [ "nowatchdog" "nmi_watchdog=0" ];
}
