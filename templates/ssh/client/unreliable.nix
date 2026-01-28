{ lib, ... }:
{
  programs.ssh.matchBlocks."remote-field-*" = {
    user = "field";
    extraOptions = {
      ServerAliveInterval = "20";
      ServerAliveCountMax = "30";
      ConnectTimeout = "120";
      Compression = "yes";
      ConnectionAttempts = "3";
      ControlPersist = "4h";
      StrictHostKeyChecking = "accept-new";
    };
  };
}
