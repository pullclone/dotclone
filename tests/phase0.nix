{ nixpkgs, system }:
let
  pkgs = nixpkgs.legacyPackages.${system};
in
pkgs.testers.nixosTest {
  name = "nyx-phase0-login";

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

      my.security.phase = 0;
      my.security.breakglass.enable = false;
      my.security.assertions.enable = true;

      users.users.admin = {
        isNormalUser = true;
        createHome = true;
        password = "admin";
      };
    };

  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("getent passwd admin")
    machine.succeed("su - admin -c 'id -u'")
  '';
}
