{ lib, config, ... }:

let
  answersPath = "/etc/nixos/nyxos-install.nix";
  answers = if builtins.pathExists answersPath then import answersPath else {};

  hostName = answers.hostName or "nyx";
  timeZone = answers.timeZone or "UTC";
  userName = answers.userName or "ashy";
  mac = answers.mac or { mode = "default"; };
in
{
  options = {
    my.install.userName = lib.mkOption {
      type = lib.types.str;
      default = userName;
      description = "The primary username set during installation";
    };
  };

  config = {
    networking.hostName = hostName;
    time.timeZone = timeZone;

    networking.networkmanager = lib.mkIf (builtins.elem mac.mode [ "random" "stable" ]) {
      wifi.macAddress = mac.mode;
      ethernet.macAddress = mac.mode;
    };

    networking.interfaces = lib.mkIf (mac.mode == "fixed") {
      "${mac.interface}".macAddress = mac.address;
    };
  };
}
