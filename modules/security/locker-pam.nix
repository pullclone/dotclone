{ config, lib, ... }:

let
  phase = config.my.security.phase;
  user = config.my.install.userName;

  panel =
    lib.attrByPath
      [
        "home-manager"
        "users"
        user
        "my"
        "desktop"
        "panel"
      ]
      "unknown"
      config;

  noctaliaEnabled =
    lib.attrByPath
      [
        "home-manager"
        "users"
        user
        "programs"
        "noctalia-shell"
        "enable"
      ]
      false
      config;

  noctaliaLockOnSuspend =
    lib.attrByPath
      [
        "home-manager"
        "users"
        user
        "programs"
        "noctalia-shell"
        "settings"
        "general"
        "lockOnSuspend"
      ]
      false
      config;

  swaylockEnabled =
    lib.attrByPath
      [
        "home-manager"
        "users"
        user
        "programs"
        "swaylock"
        "enable"
      ]
      false
      config;

  activeLocker =
    if panel == "noctalia" || noctaliaEnabled then
      "noctalia"
    else if swaylockEnabled then
      "swaylock"
    else
      "unknown";
in
{
  options.my.security.locker.expected = lib.mkOption {
    type = lib.types.enum [
      "noctalia"
      "swaylock"
    ];
    default = "noctalia";
    description = ''
      Locker expected to handle idle/suspend and manual lock flows. Used for audit
      assertions in staged/enforced security phases.
    '';
  };

  config = lib.mkIf (phase >= 0) {
    my.security.locker.active = activeLocker;

    assertions = lib.mkIf (phase >= 1) [
      {
        assertion = !(noctaliaEnabled && swaylockEnabled);
        message = "Locker audit: only one locker should be active; both noctalia-shell and swaylock are enabled.";
      }
      {
        assertion = activeLocker != "unknown";
        message = "Locker audit: unable to detect an active locker (noctalia or swaylock).";
      }
      {
        assertion = (activeLocker != "noctalia") || noctaliaLockOnSuspend;
        message = "Locker audit: Noctalia is active but lockOnSuspend is disabled.";
      }
      {
        assertion =
          (activeLocker == config.my.security.locker.expected)
          || (config.my.security.locker.expected == "swaylock" && swaylockEnabled)
          || (config.my.security.locker.expected == "noctalia" && noctaliaEnabled);
        message = "Locker audit: active locker does not match expected locker.";
      }
    ];
  };
}
