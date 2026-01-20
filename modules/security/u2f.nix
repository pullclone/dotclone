{ config, lib, ... }:

let
  phase = config.my.security.phase;
  cfg = config.my.security.u2f;

  defaultMode = if phase >= 2 then "required" else "optional";
  control = if cfg.mode == "required" then "required" else "sufficient";
in
{
  options.my.security.u2f = {
    enable = lib.mkEnableOption "pam_u2f hardening gated by security phase" // {
      default = true;
    };

    mode = lib.mkOption {
      type = lib.types.enum [
        "optional"
        "required"
      ];
      default = lib.mkDefault defaultMode;
      description = ''
        U2F enforcement level. "optional" keeps password fallback (phase 1),
        "required" enforces U2F for enrolled users (phase 2).
      '';
    };

    authFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/u2f-mappings";
      description = ''
        Central authfile for pam_u2f mappings (generated with pamu2fcfg).
        Keep the break-glass user unenrolled to allow password-only fallback.
      '';
    };

    bypassGroup = lib.mkOption {
      type = lib.types.str;
      default = "u2f-bypass";
      description = "Group for users exempt from U2F (break-glass path).";
    };

    services = {
      doas.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable U2F on doas (primary escalation surface).";
      };
      locker.enable = lib.mkOption {
        type = lib.types.bool;
        default = phase >= 2;
        description = "Enable U2F on lockers (swaylock/Noctalia PAM services). Leave false until stable.";
      };
      login.enable = lib.mkOption {
        type = lib.types.bool;
        default = phase >= 2;
        description = "Enable U2F on login/display-manager PAM. Leave false until stable.";
      };
    };
  };

  config = lib.mkIf (phase >= 1 && cfg.enable) {
    # Central U2F settings; nouserok allows the break-glass user without key.
    security.pam.u2f = {
      enable = true;
      control = control;
      settings = {
        authfile = cfg.authFile;
        cue = true;
        nouserok = true;
      };
    };

    # Break-glass group (opt-in for exempt users).
    users.groups.${cfg.bypassGroup} = { };

    # Attach U2F to target PAM services.
    security.pam.services.doas.u2fAuth = cfg.services.doas.enable;
    security.pam.services.swaylock.u2fAuth = lib.mkIf cfg.services.locker.enable true;
    security.pam.services.login.u2fAuth = lib.mkIf cfg.services.login.enable true;

    assertions = [
      {
        assertion = config.my.security.breakglass.enable;
        message = "U2F staged/enforced requires my.security.breakglass.enable = true.";
      }
    ];
  };
}
