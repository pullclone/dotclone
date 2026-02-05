{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.my.install.autoUpgrade;
  host = config.networking.hostName;
  cadence = if cfg.cadence == "daily" then "daily" else "weekly";
  rebootFlag = lib.optionalString cfg.allowReboot " --reboot";
  rebuildCmd = "${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake /etc/nixos#${host}${rebootFlag}";
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.nyxos-auto-upgrade = {
      description = "NyxOS automatic upgrade (flake-based)";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = rebuildCmd;
      };
    };

    systemd.timers.nyxos-auto-upgrade = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cadence;
        Persistent = true;
      };
    };
  };
}
