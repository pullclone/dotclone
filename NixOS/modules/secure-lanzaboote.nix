# modules/secure-boot-lanzaboote.nix
{ pkgs, lib, ... }:
{
  imports = [ inputs.lanzaboote.nixosModules.lanzaboote ];

  environment.systemPackages = [ pkgs.sbctl ];

  # Lanzaboote replaces systemd-boot module, so force it off.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
}
