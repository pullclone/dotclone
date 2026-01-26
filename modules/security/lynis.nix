{ config, lib, pkgs, ... }:

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

    systemd.timers.lynis-audit = lib.mkIf cfg.timer.enable {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
      unitConfig.Description = "Weekly Lynis audit";
    };
  };
}
