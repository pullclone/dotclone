{ nixpkgs, system }:
let
  lib = nixpkgs.lib;
  pkgs = nixpkgs.legacyPackages.${system};

  attempt = builtins.tryEval (
    lib.nixosSystem {
      inherit system;
      modules = [
        ../modules/security/phase.nix
        ../modules/security/access.nix
        (
          { lib, ... }:
          {
            options.my.install.userName = lib.mkOption {
              type = lib.types.str;
              default = "admin";
            };

            config.my.install.userName = "admin";
          }
        )
        {
          system.stateVersion = "25.11";
          my.security.phase = 1;
          my.security.breakglass.enable = false;
          my.security.assertions.enable = true;
          my.security.access.adminUsers = [ "admin" ];
          users.users.admin = {
            isNormalUser = true;
            createHome = true;
          };
        }
      ];
    }
  );

  _ = lib.assertMsg (!attempt.success) ''
    Expected evaluation failure when my.security.phase >= 1 and breakglass is disabled.
  '';

in
pkgs.runCommand "nyx-breakglass-required" { } ''
  echo "ok" > $out
''
