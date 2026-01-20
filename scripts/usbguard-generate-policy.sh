#!/usr/bin/env bash
set -euo pipefail

rule_file="${1:-/etc/usbguard/rules.conf}"
timestamp="$(date -u +%Y%m%d-%H%M%S)"
backup="${rule_file}.bak-${timestamp}"
tmp="$(mktemp)"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

require_cmd usbguard
require_cmd install

if [[ $EUID -ne 0 ]]; then
  echo "This script must run as root (use doas/sudo): $0 [rule-file]" >&2
  exit 1
fi

echo "Generating USBGuard allowlist from currently attached devices..."
echo "Target:  ${rule_file}"
echo "Backup:  ${backup}"

mkdir -p "$(dirname "$rule_file")"
usbguard generate-policy > "$tmp"

if [[ -f "$rule_file" ]]; then
  install -m 0600 "$rule_file" "$backup"
fi

install -m 0600 "$tmp" "$rule_file"
rm -f "$tmp"

echo "Done. Review ${rule_file}, then rebuild:"
echo "  doas nixos-rebuild test --flake .#<target>"
echo "For soft enforcement, set my.security.usbguard.softEnforce = true and rebuild once ready."
