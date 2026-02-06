{ config, lib, ... }:

let
  cfg = config.my.security.secrets;
in
{
  options.my.security.secrets = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sops-nix secret management.";
    };

    ageKeyFile = lib.mkOption {
      type = lib.types.path;
      default = "/persist/keys/age/keys.txt";
      description = ''
        Path to the age private key file used by sops-nix.
        Private key material lives on persist storage and must never be committed to the repo.
      '';
    };

    defaultSopsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "./secrets/example.yaml.sops";
      description = ''
        Optional default encrypted sops file. Keep this null unless you want a global default.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # sops-nix renders declared secrets under /run/secrets by default.
        sops.age.keyFile = cfg.ageKeyFile;
      }
      (lib.mkIf (cfg.defaultSopsFile != null) {
        sops.defaultSopsFile = cfg.defaultSopsFile;
      })
    ]
  );
}
