{ config, lib, ... }:

let
  phase = config.my.security.phase;
  ukiEnabled = config.my.boot.uki.enable;

  extension = {
    "nyxos.uki" = {
      osRelease = "/etc/os-release";
      hostName = config.networking.hostName;
      profile = config.my.install.profile.system or "unknown";
      systemProfile = config.systemProfile or "unknown";
    };
  };
in
{
  config = lib.mkIf (phase >= 1 && ukiEnabled) {
    boot.bootspec = {
      enable = true;
      extensions = extension;
    };

    # Keep UKI outputs deterministic for build-only CI jobs; no enrollment yet.
    system.build.ukiSpec = config.system.build.bootspec;
  };
}
