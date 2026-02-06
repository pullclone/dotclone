{
  config,
  lib,
  pkgs,
  ...
}:

let
  phase = config.my.security.phase;
  cfg = config.my.security.usbguard;
  breakglassEnabled = config.my.security.breakglass.enable;
  effectiveRuleFile = if cfg.policyPath != null then cfg.policyPath else cfg.ruleFile;
  learnAllowed = phase <= 1 && breakglassEnabled;
  learnActive = cfg.enable && cfg.learn.enable && learnAllowed;
  usbguardActive = cfg.enable && (phase >= 1 || learnActive);
  learnDuration = toString cfg.learn.durationMinutes;
  learnTarget = toString effectiveRuleFile;
in
{
  options.my.security.usbguard = {
    enable = lib.mkEnableOption "USBGuard gated by security phase" // {
      default = true;
    };

    ruleFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/usbguard/rules.conf";
      description = "Path to the USBGuard rules file (allowlist).";
    };

    policyPath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Optional USBGuard policy path. Set this to a persist-backed path
        such as /persist/etc/usbguard/rules.conf.
      '';
    };

    softEnforce = lib.mkOption {
      type = lib.types.bool;
      default = phase >= 2;
      description = ''
        When true (phase >=1), block unknown devices instead of allowing them.
        Keep disabled while collecting an allowlist. Recovery: switch to a local
        TTY, run `doas usbguard generate-policy > /etc/usbguard/rules.conf` to
        refresh rules, then rebuild or toggle softEnforce back to false.
      '';
    };

    learn = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Enable USBGuard learn mode on boot. Learn mode runs USBGuard in allow mode,
          waits for the configured window, then generates a machine-specific policy.
          This mode is only valid in phase 0/1 with break-glass enabled.
        '';
      };

      durationMinutes = lib.mkOption {
        type = lib.types.int;
        default = 10;
        description = "Learn mode window before policy generation (minutes).";
      };
    };
  };

  config = lib.mkMerge [
    # Ship a default policy from the repo unless a persist-backed policy path is supplied.
    (lib.mkIf (cfg.policyPath == null) {
      environment.etc."usbguard/rules.conf".source = ../../etc/usbguard/rules.conf;
    })

    {
      systemd.tmpfiles.rules = [
        "d /var/log/usbguard 0750 root root -"
      ];
    }

    (lib.mkIf usbguardActive {
      services.usbguard = {
        enable = true;
        ruleFile = effectiveRuleFile;
        implicitPolicyTarget =
          if learnActive then
            "allow"
          else if cfg.softEnforce then
            "block"
          else
            "allow";
        presentDevicePolicy = "apply-policy";
        insertedDevicePolicy = "apply-policy";
        IPCAllowedUsers = [
          "root"
          config.my.install.userName
        ];
      };
    })

    (lib.mkIf learnActive {
      systemd.services.usbguard-learn-policy = {
        description = "Generate USBGuard policy after learn-mode window";
        wantedBy = [ "multi-user.target" ];
        after = [ "usbguard.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -euo pipefail

          target="${learnTarget}"
          tmp="$(${pkgs.coreutils}/bin/mktemp /run/usbguard-policy.XXXXXX)"
          cleanup() {
            ${pkgs.coreutils}/bin/rm -f "$tmp" || true
          }
          trap cleanup EXIT

          ${pkgs.coreutils}/bin/sleep ${learnDuration}m
          ${pkgs.usbguard}/bin/usbguard generate-policy > "$tmp"
          if [[ ! -s "$tmp" ]]; then
            echo "usbguard-learn-policy: generated policy is empty." >&2
            exit 1
          fi

          target_dir="$(${pkgs.coreutils}/bin/dirname "$target")"
          ${pkgs.coreutils}/bin/install -d -m 0700 "$target_dir"
          ${pkgs.coreutils}/bin/install -m 0600 -o root -g root "$tmp" "$target"

          echo "usbguard-learn-policy: wrote policy to $target"
        '';
      };
    })

    {
      assertions =
        (lib.optionals (phase >= 1 && cfg.enable) [
          {
            assertion = breakglassEnabled;
            message = "USBGuard staged/enforced requires my.security.breakglass.enable = true.";
          }
        ])
        ++ [
          {
            assertion = cfg.learn.durationMinutes > 0;
            message = "my.security.usbguard.learn.durationMinutes must be > 0.";
          }
          {
            assertion = (!cfg.learn.enable) || breakglassEnabled;
            message = "USBGuard learn mode requires my.security.breakglass.enable = true.";
          }
          {
            assertion = (!cfg.learn.enable) || (phase <= 1);
            message = "USBGuard learn mode is only allowed in security phase 0 or 1.";
          }
          {
            assertion = (!cfg.learn.enable) || (cfg.policyPath != null);
            message = "USBGuard learn mode requires my.security.usbguard.policyPath to be set (for example /persist/etc/usbguard/rules.conf).";
          }
        ];
    }
  ];
}
