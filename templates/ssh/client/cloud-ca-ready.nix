{ lib, ... }:
{
  programs.ssh.matchBlocks."cloud-ca-*" = {
    extraOptions = {
      StrictHostKeyChecking = "yes";
      UserKnownHostsFile = "~/.ssh/known_hosts_ca";
      UpdateHostKeys = "no";
    };
  };
}
