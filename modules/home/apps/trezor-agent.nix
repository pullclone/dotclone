{ config, pkgs, lib, ... }:

let
  cfg = config.my.identity.trezorAgent;
in
{
  options.my.identity.trezorAgent = {
    enable = lib.mkEnableOption "trezor-agent for SSH/Git signing";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      trezor-agent
      trezor-udev-rules
    ];

    services.trezor-agent = {
      enable = true;
      package = pkgs.trezor-agent;
      extraOptions = [ "--with-ssh-agent=auto" ];
    };

    programs.ssh = {
      enable = true;
      extraConfig = ''
        Host *
          IdentityAgent ${config.home.homeDirectory}/.trezor-agent/ssh-agent.sock
      '';
    };

    programs.git = {
      signing = {
        signByDefault = false; # flip to true once verified
        key = "ssh-ed25519"; # trezor-agent exports SSH keys; adjust once enrolled
      };
      extraConfig = {
        gpg = {
          format = "ssh";
          ssh.program = "${pkgs.trezor-agent}/bin/trezor-agent-git";
        };
        # Avoid agent races; force SSH to use the trezor-agent socket.
        core.sshCommand = "ssh -o IdentityAgent=${config.home.homeDirectory}/.trezor-agent/ssh-agent.sock";
      };
    };

    # Udev rules for access to the device (system-level; ensure group membership if needed)
    services.udev.packages = [ pkgs.trezor-udev-rules ];
  };
}
