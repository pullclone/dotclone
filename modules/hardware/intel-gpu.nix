{ config, lib, ... }:

{
  config = lib.mkIf config.my.install.hardware.gpu.hasIntel {
    # Placeholder for Intel GPU tuning (no defaults yet).
  };
}
