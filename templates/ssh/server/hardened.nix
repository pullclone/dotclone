{ lib, ... }:
{
  services.openssh = {
    enable = true;

    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      AllowAgentForwarding = false;
      AllowTcpForwarding = false;
      PermitTunnel = false;

      MaxAuthTries = 3;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };

    extraConfig = ''
      AllowUsers myuser admin
      LogLevel VERBOSE

      Subsystem sftp internal-sftp -l INFO
      Banner /etc/ssh/banner.txt
    '';
  };

  environment.etc."ssh/banner.txt".text = ''
    Authorized access only. All activity is monitored.
  '';
}
