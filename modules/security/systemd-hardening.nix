{ lib, ... }:

{
  # Apply NoNewPrivileges globally via systemd manager default; services can
  # override with serviceConfig.NoNewPrivileges = false (use mkForce if needed).
  systemd.extraConfig = ''
    DefaultNoNewPrivileges=yes
  '';
}
