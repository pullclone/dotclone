{ lib, ... }:
{
  programs.ssh.matchBlocks = {
    "*.compute.amazonaws.com" = {
      user = "ec2-user";
      identityFile = "~/.ssh/aws_ed25519";
      identitiesOnly = true;

      extraOptions = {
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "~/.ssh/known_hosts.aws";
        ControlPersist = "5m";
      };
    };
  };

}
