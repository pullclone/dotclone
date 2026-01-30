{ lib, ... }:
{
  programs.ssh.matchBlocks = {
    "bastion" = {
      hostname = "bastion.company.com";
      user = "myuser";
      identityFile = "~/.ssh/bastion_ed25519";
      identitiesOnly = true;

      extraOptions = {
        ControlMaster = "auto";
        ControlPath = "~/.ssh/cm/bastion-%C";
        ControlPersist = "10m";
      };
    };

    "internal-*" = {
      proxyJump = "bastion";
      user = "myuser";
      identityFile = "~/.ssh/internal_ed25519";
      identitiesOnly = true;

      extraOptions = {
        StrictHostKeyChecking = "yes";
        UserKnownHostsFile = "~/.ssh/known_hosts.internal";
      };
    };
  };
}
