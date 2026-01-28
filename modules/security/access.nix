{ config, lib, ... }:

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

    security = {
      sudo.enable = lib.mkForce false;
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
