{ config, lib, pkgs, ... }:

{
  # ==========================================
  # BOOTLOADER BASELINE
  # ==========================================
  # Designed for systemd-boot now, easy migration to UKI/Lanzaboote later.

  boot.loader.systemd-boot = {
    enable = true;
    editor = false;
    configurationLimit = 10;
  };

  boot.loader.efi.canTouchEfiVariables = true;

  # Mount ESP at /boot (Standard NixOS layout, best for Lanzaboote)
  # This assumes your hardware-configuration.nix mounts the ESP here.

  # ==========================================
  # MODERN INITRD
  # ==========================================
  # systemd in initrd is required for TPM2 unlocking and complex setups later.
  boot.initrd.systemd.enable = true;

  # ==========================================
  # KERNEL BASELINE
  # ==========================================
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Generic graphical boot parameters
  boot.kernelParams = [
    "quiet"
    "splash"
  ];

  boot.plymouth.enable = true;

  # Microcode updates (critical for AMD Strix Point)
  hardware.cpu.amd.updateMicrocode = true;
}
