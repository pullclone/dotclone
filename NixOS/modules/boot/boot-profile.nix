{ lib, config, pkgs, inputs, ... }:

let
  cfg = config.my.boot;
in
{
  options.my.boot = {
    secureBoot.enable = lib.mkEnableOption "Secure Boot via Lanzaboote";
    uki.enable = lib.mkEnableOption "Standard systemd-boot / UKI baseline";
  };

  config = lib.mkMerge [
    # -----------------------------
    # GUARDS
    # -----------------------------
    {
      assertions = [
        {
          assertion = !(cfg.uki.enable && cfg.secureBoot.enable);
          message = "NyxOS: Choose exactly one of my.boot.uki.enable or my.boot.secureBoot.enable.";
        }
      ];
    }

    # -----------------------------
    # COMMON BOOT CONFIGURATION
    # -----------------------------
    # These apply regardless of which bootloader method is chosen
    (lib.mkIf (cfg.uki.enable || cfg.secureBoot.enable) {
      # Modern initrd plumbing
      boot.initrd.systemd.enable = true;

      # EFI Handling
      boot.loader.efi.canTouchEfiVariables = true;

      # Kernel Baseline
      boot.kernelPackages = pkgs.linuxPackages_latest;

      # Generic visual params (Hardware-specific params are in hardware/amd-gpu.nix)
      boot.kernelParams = [
        "quiet"
        "splash"
      ];

      boot.plymouth.enable = true;

      # Critical for AMD Strix Point stability
      hardware.cpu.amd.updateMicrocode = true;
    })

    # -----------------------------
    # OPTION A: STANDARD / UKI
    # -----------------------------
    (lib.mkIf cfg.uki.enable {
      boot.loader.systemd-boot = {
        enable = true;
        editor = false;
        configurationLimit = 10;
      };
    })

    # -----------------------------
    # OPTION B: SECURE BOOT
    # -----------------------------
    (lib.mkIf cfg.secureBoot.enable {
      imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

      environment.systemPackages = [ pkgs.sbctl ];

      # Lanzaboote replaces the systemd-boot module logic
      boot.loader.systemd-boot.enable = lib.mkForce false;

      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/var/lib/sbctl";
      };
    })
  ];
}
