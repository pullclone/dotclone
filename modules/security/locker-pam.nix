{ config, lib, ... }:

let
  phase = config.my.security.phase;
  user = config.my.install.userName;

  installPanel = lib.attrByPath [
    "my"
    "install"
    "desktop"
    "panel"
  ] "noctalia" config;

  panel = lib.attrByPath [
    "home-manager"
    "users"
    user
    "my"
    "desktop"
    "panel"
  ] installPanel config;

  noctaliaEnabled = lib.attrByPath [
    "home-manager"
    "users"
    user
    "programs"
    "noctalia-shell"
    "enable"
  ] false config;

  swaylockEnabled = lib.attrByPath [
    "home-manager"
    "users"
    user
    "programs"
    "swaylock"
    "enable"
  ] false config;

  noctaliaPamService = "noctalia-shell";
  swaylockPamService = "swaylock";

  expectedLocker = if panel == "waybar" then "swaylock" else "noctalia";

  expectedPamService =
    if expectedLocker == "swaylock" then
      swaylockPamService
    else
      noctaliaPamService;

  expectedUserService =
    if expectedLocker == "swaylock" then
      "swaylock"
    else
      "noctalia-lock";

  lockTargetWantedBy = lib.attrByPath [
    "home-manager"
    "users"
    user
    "systemd"
    "user"
    "services"
    expectedUserService
    "Install"
    "WantedBy"
  ] [ ] config;

  lockTargetEnabled = lib.elem "lock.target" lockTargetWantedBy;

  activeLocker =
    if panel == "noctalia" && noctaliaEnabled then
      "noctalia"
    else if panel == "waybar" && swaylockEnabled then
      "swaylock"
    else if noctaliaEnabled then
      "noctalia"
    else if swaylockEnabled then
      "swaylock"
    else
      "unknown";
in
{
  options.my.security.locker.active = lib.mkOption {
    type = lib.types.enum [
      "noctalia"
      "swaylock"
      "unknown"
    ];
    readOnly = true;
    description = "Detected active locker (computed).";
  };

  options.my.security.locker.expected = lib.mkOption {
    type = lib.types.enum [
      "noctalia"
      "swaylock"
    ];
    default = expectedLocker;
    description = ''
      Locker expected to handle idle/suspend and manual lock flows. Used for audit
      assertions in staged/enforced security phases.
    '';
  };

  options.my.security.pam.targets = lib.mkOption {
    type = with lib.types; listOf str;
    default = [
      "login"
      "doas"
      expectedPamService
    ];
    description = "PAM services that should receive additional auth controls (U2F/fingerprint).";
  };

  config = lib.mkIf (phase >= 0) {
    my.security.locker.active = activeLocker;

    services.systemd-lock-handler.enable = true;

    security.pam.services = {
      swaylock = { };
      ${noctaliaPamService} = { };
    };

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
        assertion =
          (activeLocker == config.my.security.locker.expected)
          || (config.my.security.locker.expected == "swaylock" && swaylockEnabled)
          || (config.my.security.locker.expected == "noctalia" && noctaliaEnabled);
        message = "Locker audit: active locker does not match expected locker.";
      }
      {
        assertion = lib.elem expectedPamService config.my.security.pam.targets;
        message = "Locker audit: my.security.pam.targets must include the active locker PAM service.";
      }
      {
        assertion = lockTargetEnabled;
        message = "Locker audit: expected lock service must be wanted by lock.target.";
      }
    ];
  };
}
