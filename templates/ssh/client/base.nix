{ lib, ... }:
{
  programs.ssh = {
    enable = true;
    matchBlocks."*" = { };

    extraConfig = ''
      ## Identity & auth safety
      IdentitiesOnly yes
      PreferredAuthentications publickey

      ## Host verification
      HashKnownHosts yes
      StrictHostKeyChecking ask

      ## No forwarding by default
      ForwardAgent no
      ForwardX11 no
      ForwardX11Trusted no
      PermitLocalCommand no

      ## Connection reliability
      ServerAliveInterval 60
      ServerAliveCountMax 5

      ## Logging
      LogLevel INFO
    '';
  };
}
