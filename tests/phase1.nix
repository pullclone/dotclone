{ nixpkgs, system }:
let
  pkgs = nixpkgs.legacyPackages.${system};
in
pkgs.testers.nixosTest {
  name = "nyx-phase1-escalation";

  nodes.machine =
    { ... }:
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
    machine.succeed("test -x /run/current-system/sw/bin/doas")
    machine.succeed("grep -Eq 'permit.*admin' /etc/doas.conf")
    machine.fail("grep -Eq 'permit.*alice' /etc/doas.conf")
  '';
}
