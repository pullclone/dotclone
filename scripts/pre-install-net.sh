#!/usr/bin/env bash
set -euo pipefail

CONFIG="/etc/nixos/configuration.nix"

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not found; run as root" >&2
    exit 1
  fi
  SUDO="sudo"
else
  SUDO=""
fi

if ! $SUDO test -f "$CONFIG"; then
  echo "Missing $CONFIG" >&2
  exit 1
fi

backup="${CONFIG}.bak.$(date +%Y%m%d%H%M%S)"
$SUDO cp -a "$CONFIG" "$backup"

tmp="$(mktemp)"
$SUDO awk '
  /^[[:space:]]*services\.openssh\.enable[[:space:]]*=/ {next}
  /^[[:space:]]*networking\.enableIPv6[[:space:]]*=/ {next}
  /^[[:space:]]*networking\.firewall\.allowPing[[:space:]]*=/ {next}
  {lines[++n]=$0; if ($0 ~ /^[[:space:]]*}$/) last=n}
  END {
    if (n==0) {
      print "{"
      print "  services.openssh.enable = false;"
      print "  networking.enableIPv6 = false;"
      print "  networking.firewall.allowPing = false;"
      print "}"
      exit
    }
    if (last==0) {
      for (i=1;i<=n;i++) print lines[i]
      print ""
      print "  services.openssh.enable = false;"
      print "  networking.enableIPv6 = false;"
      print "  networking.firewall.allowPing = false;"
      exit
    }
    for (i=1;i<=n;i++) {
      if (i==last) {
        print "  services.openssh.enable = false;"
        print "  networking.enableIPv6 = false;"
        print "  networking.firewall.allowPing = false;"
      }
      print lines[i]
    }
  }
' "$CONFIG" > "$tmp"
$SUDO mv "$tmp" "$CONFIG"

$SUDO nixos-rebuild switch
