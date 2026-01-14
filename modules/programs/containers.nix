{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.my.programs.containers.enable = lib.mkEnableOption "Containers (Podman + Distrobox)";

  config = lib.mkIf config.my.programs.containers.enable {
    virtualisation = {
      podman = {
        enable = true;
        dockerCompat = true;
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    environment.systemPackages = with pkgs; [
      podman
      distrobox
      podman-compose
    ];
  };
}
