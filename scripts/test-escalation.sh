#!/usr/bin/env bash
set -euo pipefail
echo "Testing doas..."
if doas id -u >/dev/null 2>&1; then
  echo "doas OK for admin user"
else
  echo "doas failed" >&2
  exit 1
fi
if sudo -n true >/dev/null 2>&1; then
  echo "sudo available"
else
  echo "sudo not enabled (expected if sudoFallback.enable = false)"
fi
