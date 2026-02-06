{ nixpkgs, system }:
let
  pkgs = nixpkgs.legacyPackages.${system};
in
pkgs.testers.nixosTest {
  name = "nyx-phase1-doas-exec";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
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
      ];

      system.stateVersion = "25.11";

      my.security.phase = 1;
      my.security.breakglass.enable = true;
      my.security.assertions.enable = true;
      my.security.access.adminUsers = [ "admin" ];

      # Test-only: allow admin doas without a password to avoid PTY prompts.
      security.doas.extraRules = lib.mkForce [
        {
          users = [ "admin" ];
          runAs = "root";
          keepEnv = false;
          persist = false;
          noPass = true;
        }
      ];

      users.users.admin = {
        isNormalUser = true;
        createHome = true;
        password = "admin";
      };

      users.users.alice = {
        isNormalUser = true;
        createHome = true;
        password = "alice";
      };
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("su - admin -c 'doas id -u | grep -qx 0'")
    machine.succeed("su - admin -c \"doas sh -lc 'test \\\"$(id -u)\\\" -eq 0'\"")
    machine.fail("su - alice -c 'doas id -u'")
  '';
}
