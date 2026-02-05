{ config, lib, ... }:

let
  phase = config.my.security.phase;
  cfg = config.my.security.u2f;
  pamTargets = config.my.security.pam.targets;

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
    security.pam.services = lib.genAttrs pamTargets (_: {
      u2fAuth = true;
    });

    assertions = [
      {
        assertion = config.my.security.breakglass.enable;
        message = "U2F staged/enforced requires my.security.breakglass.enable = true.";
      }
    ];
  };
}
