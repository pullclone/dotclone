{ config, lib, ... }:

let
  phase = config.my.security.phase;
  cfg = config.my.security.usbguard;
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

    softEnforce = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        When true (phase >=1), block unknown devices instead of allowing them.
        Keep disabled while collecting an allowlist. Recovery: switch to a local
        TTY, run `doas usbguard generate-policy > /etc/usbguard/rules.conf` to
        refresh rules, then rebuild or toggle softEnforce back to false.
      '';
    };
  };

  config = {
    # Ship a default rules file so allowlist generation has a target.
    environment.etc."usbguard/rules.conf".source = ../../etc/usbguard/rules.conf;

    systemd.tmpfiles.rules = [
      "d /var/log/usbguard 0750 root root -"
    ];

    services.usbguard = lib.mkIf (phase >= 1 && cfg.enable) {
      enable = true;
      ruleFile = cfg.ruleFile;
      implicitPolicyTarget = if cfg.softEnforce then "block" else "allow";
      presentDevicePolicy = "apply-policy";
      insertedDevicePolicy = "apply-policy";
      IPCAllowedUsers = [
        "root"
        config.my.install.userName
      ];
    };

    assertions = lib.mkIf (phase >= 1 && cfg.enable) [
      {
        assertion = config.my.security.breakglass.enable;
        message = "USBGuard staged/enforced requires my.security.breakglass.enable = true.";
      }
    ];
  };
}
