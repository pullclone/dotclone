{
  config,
  lib,
  pkgs,
  ...
}:

let
  phase = config.my.security.phase;
  cfg = config.my.security.lynis;
  logDir = "/var/log/nyxos/lynis";
in
{
  options.my.security.lynis.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Lynis availability (one-shot audit + optional timer). Safe in all phases.";
  };

  options.my.security.lynis.timer.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable periodic Lynis audit timer.";
  };

  options.my.security.lynis.frequency = lib.mkOption {
    type = lib.types.enum [
      "daily"
      "weekly"
      "monthly"
      "off"
    ];
    default = "weekly";
    description = "How often to run Lynis audits when the timer is enabled. Set to \"off\" to disable.";
  };

  config = lib.mkIf (phase >= 0 && cfg.enable) {
    environment.systemPackages = [ pkgs.lynis ];

    systemd.tmpfiles.rules = [
      "d ${logDir} 0750 root root -"
    ];

    systemd.services.lynis-audit = {
      description = "Run Lynis audit and store report";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = [
          "/bin/sh"
          "-c"
          ''
            install -d -m 0750 ${logDir}
            ts=$(date -Iseconds)
            outdir="${logDir}/''${ts}"
            mkdir -p "$outdir"
            ${pkgs.lynis}/bin/lynis audit system --quiet --logfile "$outdir/lynis.log" --report-file "$outdir/report.dat"
            echo "Lynis report: $outdir"
          ''
        ];
      };
    };

    systemd.timers.lynis-audit = {
      enable = cfg.timer.enable && cfg.frequency != "off";
      wantedBy = lib.optionals (cfg.timer.enable && cfg.frequency != "off") [ "timers.target" ];
      timerConfig = lib.optionalAttrs (cfg.timer.enable && cfg.frequency != "off") {
        OnCalendar = cfg.frequency;
        Persistent = true;
      };
      unitConfig.Description = "Scheduled Lynis audit";
    };
  };
}
