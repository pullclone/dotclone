{ config, lib, ... }:

let
  cfg = config.my.security.timeSync;
  defaultNtsServers = [
    "time.cloudflare.com"
    "time1.nts.netnod.se"
    "time2.nts.netnod.se"
  ];
  ntsLines = lib.concatMapStrings (server: "server ${server} iburst nts\n") cfg.ntsServers;
in
{
  options.my.security.timeSync.ntsServers = lib.mkOption {
    type = with lib.types; listOf str;
    default = defaultNtsServers;
    example = [
      "time.cloudflare.com"
      "time-a.example.net"
    ];
    description = ''
      NTS-capable time sources for Chrony. Set to an empty list to disable
      the default servers and provide your own.
    '';
  };

  config = {
    services.chrony = {
      enable = true;
      # NTS is enabled per-server via "nts" option.
      extraConfig = ''
        ${ntsLines}
        makestep 0.5 3
        rtcsync
      '';
    };
  };
}
