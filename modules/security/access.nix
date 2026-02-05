{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.security.access;
  phase = config.my.security.phase;
  breakglass = config.my.security.breakglass.enable;
in
{
  options.my.security.access = {
    adminUsers = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ config.my.install.userName ];
      example = [
        "ashy"
        "breakglass"
      ];
      description = ''
        Accounts allowed to escalate with doas when security phase is staged/enforced (>=1).
        Keep this list minimal; at least one admin must remain to avoid lockout.
      '';
    };
    sudoFallback.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        When true, sudo will be enabled for admin users alongside doas.
        Even when false, the sudo package remains installed for emergency shells.
      '';
    };
  };

  config = lib.mkIf (phase >= 1) {
    assertions = [
      {
        assertion = breakglass;
        message = "Security phase >=1 requires my.security.breakglass.enable = true.";
      }
      {
        assertion = cfg.adminUsers != [ ];
        message = "At least one admin user must be defined for doas when security phase >=1.";
      }
    ];

    environment.systemPackages = [ pkgs.sudo ];

    security = {
      sudo.enable = lib.mkForce cfg.sudoFallback.enable;
      doas = {
        enable = lib.mkForce true;
        extraRules = lib.mkForce [
          {
            users = cfg.adminUsers;
            runAs = "root";
            keepEnv = false;
            persist = false;
            noPass = false;
          }
        ];
      };
    };

    # Guard SSH root access while tightening escalation.
    services.openssh.settings.PermitRootLogin = lib.mkForce "no";
  };
}
