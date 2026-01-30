{ lib, ... }:
{
  programs.ssh.matchBlocks."old-nas" = {
    hostname = "192.168.1.50";
    user = "admin";

    extraOptions = {
      HostKeyAlgorithms = "+ssh-rsa";
      PubkeyAcceptedAlgorithms = "+ssh-rsa";
      StrictHostKeyChecking = "yes";
      UserKnownHostsFile = "~/.ssh/known_hosts.legacy";
    };
  };
}
