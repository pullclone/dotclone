{ config, lib, pkgs, ... }:

let
  homeDir = config.home.homeDirectory;
  brave = lib.getExe pkgs.brave;

  waylandFlags = [ "--ozone-platform=wayland" "--enable-features=UseOzonePlatform" ];

  mkBraveWebApp = { id, name, url, icon, categories ? [ ] }: {
    inherit name categories;
    terminal = false;
    icon = "${homeDir}/nixdots/assets/icons/${icon}";
    comment = "${name} (web app)";

    exec = lib.concatStringsSep " " ([
      "env"
      "MOZ_ENABLE_WAYLAND=1"
      brave
      "--password-store=gnome"
      "--app=${url}"
      "--user-data-dir=${homeDir}/.local/share/brave-webapps/${id}"
    ] ++ waylandFlags);
  };
in
{
  xdg.desktopEntries = {
    discord = mkBraveWebApp {
      id = "discord";
      name = "Discord";
      url = "https://discord.com/app";
      icon = "discord.png";
      categories = [ "Network" "InstantMessaging" ];
    };
    bluesky = mkBraveWebApp {
      id = "bluesky";
      name = "Bluesky";
      url = "https://bsky.app";
      icon = "bluesky.png";
      categories = [ "Network" ];
    };
    youtube = mkBraveWebApp {
      id = "youtube";
      name = "YouTube";
      url = "https://youtube.com";
      icon = "youtube.png";
      categories = [ "AudioVideo" "Video" ];
    };
  };
}
