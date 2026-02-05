{ config, lib, ... }:

{
  boot.kernelModules = lib.mkIf (config.my.install.networking.tcp.congestionControl == "bbr") [
    "tcp_bbr"
  ];
}
