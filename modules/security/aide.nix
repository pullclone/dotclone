{
  config,
  lib,
  pkgs,
  ...
}:

let
  phase = config.my.security.phase;
  cfg = config.my.security.aide;
  stateDir = "/var/lib/nyxos/aide";
  logDir = "/var/log/nyxos/aide";
  aideConf = ''
    database=file:${stateDir}/aide.db
    database_out=file:${stateDir}/aide.db.new
    gzip_dbout=no
    verbose=5

    @@define ROOT /

    # Ignore immutable store and volatile paths
    !/nix/store
    !/tmp
    !/var/tmp
    !/run
    !/var/run
    !/dev
    !/proc
    !/sys

    ${stateDir}    NONE
    ${logDir}      NONE

    # Default rule set
    R = p+i+n+u+g+s+m+c+acl+selinux+xattrs+sha256
    ''${ROOT}        R
  '';
in
{
  options.my.security.aide.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable AIDE integrity monitoring (phase-aware, safe to toggle in phase 0+).";
  };

  config = lib.mkIf (phase >= 0 && cfg.enable) {
    environment.systemPackages = [ pkgs.aide ];
    environment.etc."aide.conf".text = aideConf;

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0700 root root -"
      "d ${logDir} 0750 root root -"
    ];

    systemd.services.aide-init = {
      description = "Initialize AIDE database";
      wantedBy = [ ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = [
          "/bin/sh"
          "-c"
          ''
            install -d -m 0700 ${stateDir}
            install -d -m 0750 ${logDir}
            ${pkgs.aide}/bin/aide --config /etc/aide.conf --init
            mv ${stateDir}/aide.db.new ${stateDir}/aide.db
            echo "AIDE database initialized at ${stateDir}/aide.db"
          ''
        ];
      };
    };

    systemd.services.aide-check = {
      description = "AIDE integrity check";
      wantedBy = [ ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = [
          "/bin/sh"
          "-c"
          ''
            install -d -m 0700 ${stateDir}
            install -d -m 0750 ${logDir}
            ts=$(date -Iseconds)
            out="${logDir}/aide-check-''${ts}.log"
            ${pkgs.aide}/bin/aide --config /etc/aide.conf --check | tee "$out"
            echo "Report: $out"
          ''
        ];
      };
    };

    systemd.timers.aide-check = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
      unitConfig.Description = "Weekly AIDE integrity check";
    };
  };
}
