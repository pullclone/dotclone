{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.my.identity.trezorAgent;
  sshSocket = "${config.home.homeDirectory}/.trezor-agent/ssh-agent.sock";
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.trezor-agent ];

    systemd.user.services.trezor-agent = {
      Unit = {
        Description = "Trezor agent";
      };
      Service = {
        ExecStart = "${pkgs.trezor-agent}/bin/trezor-agent --with-ssh-agent=auto";
        Restart = "on-failure";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks."*" = {
        identityAgent = sshSocket;
      };
    };

    programs.git = {
      signing = {
        signByDefault = false; # flip to true once verified
        key = "ssh-ed25519"; # trezor-agent exports SSH keys; adjust once enrolled
      };
      settings = {
        gpg = {
          format = "ssh";
          ssh.program = "${pkgs.trezor-agent}/bin/trezor-agent-git";
        };
        # Avoid agent races; force SSH to use the trezor-agent socket.
        core.sshCommand = "ssh -o IdentityAgent=${sshSocket}";
      };
    };
  };
}
