{ lib, ... }:
{
  programs.ssh.extraConfig = lib.mkAfter ''
    StrictHostKeyChecking yes
    LogLevel ERROR

    ServerAliveInterval 30
    ServerAliveCountMax 3
  '';
}
