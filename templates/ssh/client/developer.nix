{ lib, ... }:
{
  programs.ssh.extraConfig = lib.mkAfter ''
    AddKeysToAgent ask

    ControlMaster auto
    ControlPath %h/.ssh/cm/%C
    ControlPersist 10m
  '';

  systemd.user.tmpfiles.rules = [
    "d %h/.ssh/cm 0700 - - -"
  ];

  programs.ssh.matchBlocks = {
    "dev-*" = {
      user = "developer";
      identityFile = "~/.ssh/dev_ed25519";
      identitiesOnly = true;
      extraOptions.ForwardAgent = "yes";
    };

    "prod-*" = {
      user = "admin";
      identityFile = "~/.ssh/prod_ed25519";
      identitiesOnly = true;
      extraOptions = {
        ForwardAgent = "no";
        StrictHostKeyChecking = "yes";
      };
    };
  };
}
