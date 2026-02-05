{ config, lib, ... }:

let
  cfg = config.my.ssh;

  t = {
    server = {
      hardened = import ../../templates/ssh/server/hardened.nix;
    };
  };
in
{
  options.my.ssh.server.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable the hardened SSH server profile.";
  };

  config = lib.mkIf (cfg.enable && cfg.server.enable) (t.server.hardened { inherit lib; });
}
