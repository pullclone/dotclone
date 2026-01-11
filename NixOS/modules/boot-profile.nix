{ lib, config, pkgs, inputs, ... }:

let
  cfg = config.my.boot;
in
{
  options.my.boot = {
    secureBoot.enable = lib.mkEnableOption "Secure Boot via Lanzaboote";

    uki.enable = lib.mkEnableOption "UKI / systemd-boot baseline";
  };

  config = lib.mkMerge [

    # -----------------------------
    # UKI BASELINE (default path)
    # -----------------------------
    (lib.mkIf cfg.uki.enable {
      boot.loader.systemd-boot.enable = true;
      boot.loader.systemd-boot.editor = false;
      boot.loader.systemd-boot.configurationLimit = 10;

      boot.loader.efi.canTouchEfiVariables = true;

      boot.initrd.systemd.enable = true;

      boot.kernelPackages = pkgs.linuxPackages_latest;

      boot.kernelParams = [
        "amd_pstate=active"
        "quiet"
        "splash"
      ];

      boot.plymouth.enable = true;

      hardware.cpu.amd.updateMicrocode = true;
    })

    # -----------------------------
    # SECURE BOOT (Lanzaboote)
    # -----------------------------
    (lib.mkIf cfg.secureBoot.enable {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      environment.systemPackages = [ pkgs.sbctl ];

      # Lanzaboote replaces systemd-boot
      boot.loader.systemd-boot.enable = lib.mkForce false;

      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };
    })
  ];
}
