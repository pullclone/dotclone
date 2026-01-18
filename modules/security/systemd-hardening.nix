{ lib, ... }:

{
  # Apply NoNewPrivileges globally via systemd manager default; services can
  # override with serviceConfig.NoNewPrivileges = false (use mkForce if needed).
  systemd.settings.Manager.DefaultNoNewPrivileges = lib.mkDefault "yes";
}
