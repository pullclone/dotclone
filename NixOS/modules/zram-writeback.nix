{ config, lib, ... }:
let
  cfg = config.my.swap.writeback;
in
{
  options.my.swap.writeback = {
    enable = lib.mkEnableOption "zram writeback (optional disk-backed writeback)";
    device = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/dev/disk/by-partlabel/SWAP";
      description = ''
        Optional backing block device for zram writeback.
        If null, writeback is disabled (zram still works normally).
      '';
    };
  };

  config = lib.mkMerge [
    # --- Base ZRAM profile (always applies when this module is selected) ---
    {
      zramSwap = {
        enable = true;
        algorithm = "zstd";

        # With ~30GiB Linux-visible RAM, 50% ≈ 15GiB zram device.
        memoryPercent = lib.mkDefault 50;

        priority = lib.mkDefault 100;
      };

      # zstd + swap clustering can cause nasty latency spikes.
      boot.kernel.sysctl."vm.page-cluster" = lib.mkDefault 0;

      # Standard ZRAM swappiness
      boot.kernel.sysctl."vm.swappiness" = lib.mkDefault 120;
      boot.kernel.sysctl."vm.watermark_scale_factor" = lib.mkDefault 125;
    }

    # --- Optional writeback integration (only if enabled + device provided) ---
    (lib.mkIf (cfg.enable && cfg.device != null) {
      zramSwap.writebackDevice = cfg.device;

      # When writeback is enabled, it becomes safer to push a bit harder into swap.
      boot.kernel.sysctl."vm.swappiness" = lib.mkDefault 150;
    })
  ];
}
