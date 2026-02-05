{ config, lib, ... }:

{
  config = lib.mkIf (config.my.install.hardware.cpuVendor == "intel") {
    # Placeholder for Intel CPU tuning (no defaults yet).
  };
}
