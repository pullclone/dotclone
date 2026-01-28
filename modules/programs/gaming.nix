{
  config,
  lib,
  options,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.my.install.gaming;
  needs32Bit = cfg.steam || cfg.wine || cfg.lutris || cfg.lutrisRsi;
  anyGaming = needs32Bit || cfg.gamemode || cfg.gamescope || cfg.emulationstation;

  nixCitizenPackages = inputs.nix-citizen.packages or { };
  nixCitizenSystemPackages = nixCitizenPackages.${pkgs.system} or { };
  rsiPackage =
    if nixCitizenSystemPackages ? rsi-launcher then
      nixCitizenSystemPackages.rsi-launcher
    else if nixCitizenSystemPackages ? default then
      nixCitizenSystemPackages.default
    else if nixCitizenSystemPackages ? nix-citizen then
      nixCitizenSystemPackages.nix-citizen
    else
      null;
  lugHelper =
    if nixCitizenSystemPackages ? lug-helper then nixCitizenSystemPackages.lug-helper else null;
  rsiPackages =
    (with pkgs; [
      bash
      coreutils
      curl
      cabextract
      unzip
      winetricks
      zenity
    ])
    ++ lib.optional (rsiPackage != null) rsiPackage
    ++ lib.optional (lugHelper != null) lugHelper;
  wineWayland = if pkgs.wineWowPackages ? waylandFull then pkgs.wineWowPackages.waylandFull else null;
  hasGamescopeOption = lib.hasAttrByPath [ "programs" "gamescope" "enable" ] options;
in
{
  config = lib.mkMerge [
    (lib.mkIf anyGaming (
      lib.mkMerge [
        {
          hardware.graphics.enable = lib.mkDefault true;

          hardware.graphics.enable32Bit = lib.mkDefault needs32Bit;

          programs.steam.enable = cfg.steam;
          hardware.steam-hardware.enable = lib.mkDefault cfg.steam;

          programs.gamemode.enable = cfg.gamemode;

          security.polkit.enable = lib.mkDefault cfg.lutrisRsi;

          environment.systemPackages =
            with pkgs;
            lib.flatten [
              (lib.optionals cfg.lutris [
                lutris
              ])
              (lib.optionals cfg.wine [
                wineWowPackages.stable
                (lib.optional (wineWayland != null) wineWayland)
                winetricks
                cabextract
                unzip
              ])
              (lib.optionals cfg.emulationstation [
                emulationstation
              ])
              (lib.optionals cfg.gamescope [
                gamescope
              ])
              (lib.optionals cfg.lutrisRsi rsiPackages)
            ];
        }
        (lib.mkIf hasGamescopeOption {
          programs.gamescope.enable = cfg.gamescope;
        })
      ]
    ))
    {
      assertions = [
        {
          assertion = !(cfg.lutrisRsi && !cfg.lutris);
          message = "gaming: lutrisRsi requires lutris = true.";
        }
        {
          assertion = !(cfg.lutrisRsi && rsiPackage == null);
          message = "gaming: nix-citizen package not found in inputs.nix-citizen for this system.";
        }
      ];
    }
  ];
}
