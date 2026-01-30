{ lib, ... }:
{
  programs.ssh.extraConfig = lib.mkAfter ''
    AddKeysToAgent ask

    ControlMaster auto
    ControlPath %h/.ssh/cm/%C
    ControlPersist 30m
  '';

  systemd.user.tmpfiles.rules = [
    "d %h/.ssh/cm 0700 - - -"
  ];

  programs.ssh.matchBlocks = {
    "nas" = {
      hostname = "192.168.1.100";
      user = "admin";
      identityFile = "~/.ssh/home_ed25519";
    };
  };
}
