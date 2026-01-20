{ config, lib, ... }:

let
  phase = config.my.security.phase;
  cfg = config.my.security.fingerprint;

  setService =
    name: {
      security.pam.services.${name}.fprintAuth = true;
    };
in
{
  options.my.security.fingerprint = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable fingerprint authentication via fprintd for selected PAM services.
        Defaults to off in all phases; can be enabled in phase ≥1 for convenience
        login/locker flows. Do not use for doas.
      '';
    };

    pamServices = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [
        "login"
        "swaylock"
      ];
      description = "PAM services to enable pam_fprintd for (do not include doas).";
    };
  };

  config = lib.mkIf (phase >= 1 && cfg.enable) (lib.mkMerge (
    [
      { services.fprintd.enable = true; }
    ]
    ++ map setService cfg.pamServices
  ));
}
