{ config, lib, ... }:

let
  cfg = config.my.security;
in
{
  options.my.security = {
    phase = lib.mkOption {
      type = lib.types.enum [
        0
        1
        2
      ];
      default = 0;
      example = 1;
      description = ''
        Security rollout phase. 0 = observe/measure, 1 = staged apply with manual verification,
        2 = enforced. Modules should gate changes off this to keep rollouts sequenced.
      '';
    };

    breakglass.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the designated break-glass path (documented in docs/RECOVERY.md) before raising
        security phase above 0. Required for staged/enforced phases when assertions are enabled.
      '';
    };

    assertions.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Toggle for security-phase assertions. Leave enabled to enforce rollout guardrails;
        disable only in emergency recovery scenarios.
      '';
    };
  };

  config = {
    assertions = lib.mkIf cfg.assertions.enable [
      {
        assertion = lib.elem cfg.phase [
          0
          1
          2
        ];
        message = "my.security.phase must be 0 (observe), 1 (staged), or 2 (enforced).";
      }
      {
        assertion = (cfg.phase == 0) || cfg.breakglass.enable;
        message = "Enable my.security.breakglass before raising my.security.phase above 0.";
      }
    ];
  };
}
