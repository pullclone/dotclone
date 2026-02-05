{ config, lib, ... }:

{
  networking.enableIPv6 = lib.mkDefault config.my.install.networking.ipv6.enable;
  networking.tempAddresses = lib.mkDefault config.my.install.networking.ipv6.tempAddresses;
}
