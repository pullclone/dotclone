{ config, lib, ... }:

let
  phase = config.my.security.phase;
  cfg = config.my.security.fingerprint;
  pamTargets = builtins.filter (svc: svc != "doas") config.my.security.pam.targets;
in
{
  options.my.security.fingerprint = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable fingerprint authentication via fprintd for PAM services listed in
        my.security.pam.targets (excluding doas). Defaults to off in all phases;
        can be enabled in phase ≥1 for convenience login/locker flows.
      '';
    };

  };

  config = lib.mkIf (phase >= 1 && cfg.enable) {
    services.fprintd.enable = true;
    security.pam.services = lib.genAttrs pamTargets (_: {
      fprintAuth = true;
    });

    assertions = [
      {
        assertion = !(builtins.elem "doas" config.my.security.pam.targets);
        message = "Fingerprint auth should not target doas; remove it from my.security.pam.targets.";
      }
    ];
  };
}
