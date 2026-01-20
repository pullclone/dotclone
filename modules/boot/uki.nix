{ config, lib, ... }:

let
  phase = config.my.security.phase;
  ukiEnabled = config.my.boot.uki.enable;
  namespace = "io.pullclone.dotclone.uki";

  extension = {
    "${namespace}.osRelease" = "/etc/os-release";
    "${namespace}.hostName" = config.networking.hostName;
    "${namespace}.profile" = config.my.install.profile.system or "unknown";
    "${namespace}.systemProfile" = config.systemProfile or "unknown";
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
