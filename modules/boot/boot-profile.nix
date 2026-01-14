{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.my.boot;
in
{
  # Import Lanzaboote so its options (boot.lanzaboote.*) are available even when disabled.
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  options.my.boot = {
    secureBoot.enable = lib.mkEnableOption "Secure Boot via Lanzaboote";
    uki.enable = lib.mkEnableOption "Standard systemd-boot / UKI baseline";
  };

  config = lib.mkMerge [
    {
      # Drive boot selection from installer answers (boot.mode)
      my.boot.uki.enable = lib.mkDefault ((config.my.install.boot.mode or "uki") == "uki");
      my.boot.secureBoot.enable = lib.mkDefault ((config.my.install.boot.mode or "uki") == "secureboot");
    }

    # -----------------------------
    # GUARDS
    # -----------------------------
    {
      assertions = [
        {
          assertion = !(cfg.uki.enable && cfg.secureBoot.enable);
          message = "NyxOS: Choose exactly one of my.boot.uki.enable or my.boot.secureBoot.enable.";
        }
        {
          assertion = !(cfg.uki.enable || cfg.secureBoot.enable) || config.boot.initrd.systemd.enable;
          message = "NyxOS: boot.initrd.systemd.enable must remain true when a boot profile is selected.";
        }
        {
          assertion =
            !((config.my.install.trust.phase or "dev") == "enforced")
            || cfg.secureBoot.enable
            || cfg.uki.enable;
          message = "NyxOS: trust.phase=enforced requires a boot profile selection.";
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
