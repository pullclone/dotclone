#!/usr/bin/env bash
set -euo pipefail

echo "WARNING: Keep a root shell/TTY open while testing USBGuard to avoid lockout."
echo "Generating policy from currently connected devices..."
echo

if ! command -v usbguard >/dev/null 2>&1; then
  echo "usbguard binary not found; install usbguard and rerun." >&2
  exit 1
fi

usbguard generate-policy

cat <<'EOF'

Next steps:
1) Copy the generated rules into: etc/usbguard/rules.conf (in this repo)
2) Rebuild: sudo nixos-rebuild switch --flake .#nyx
3) Verify: systemctl status usbguard && usbguard list-devices
EOF
