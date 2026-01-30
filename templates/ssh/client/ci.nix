{ lib, ... }:
{
  programs.ssh.extraConfig = lib.mkAfter ''
    BatchMode yes
    StrictHostKeyChecking yes

    UserKnownHostsFile ~/.ssh/known_hosts_ci
    GlobalKnownHostsFile /dev/null

    ConnectTimeout 10
    ServerAliveInterval 15
    ServerAliveCountMax 2

    IdentitiesOnly yes
    UpdateHostKeys no

    LogLevel ERROR
  '';
}
