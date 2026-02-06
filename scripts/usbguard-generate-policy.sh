#!/usr/bin/env bash
set -euo pipefail

rule_file="${1:-/persist/etc/usbguard/rules.conf}"
timestamp="$(date -u +%Y%m%d-%H%M%S)"
backup="${rule_file}.bak-${timestamp}"
tmp=""

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

cleanup() {
  if [[ -n "$tmp" && -f "$tmp" ]]; then
    rm -f "$tmp" || true
  fi
}

trap cleanup EXIT

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
tmp="$(mktemp)"
if ! usbguard generate-policy > "$tmp"; then
  echo "USBGuard policy generation failed." >&2
  exit 1
fi

if [[ ! -s "$tmp" ]]; then
  echo "USBGuard policy generation produced an empty policy." >&2
  exit 1
fi

if [[ -f "$rule_file" ]]; then
  install -m 0600 -o root -g root "$rule_file" "$backup"
fi

install -m 0600 -o root -g root "$tmp" "$rule_file"
chown root:root "$rule_file"
chmod 0600 "$rule_file"

echo "USBGuard policy written to ${rule_file}."
echo "Done. Review ${rule_file}, then rebuild:"
echo "  doas nixos-rebuild test --flake .#<target>"
echo "For soft enforcement, set my.security.usbguard.softEnforce = true and rebuild once ready."
