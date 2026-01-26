#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'EOF_HELP'
Usage: rsi-launcher.sh [--lutris-setup] [--] [rsi-launcher args]

Runs the nix-citizen RSI Launcher if installed. Use --lutris-setup to
invoke the LUG helper setup for Lutris-based installs (if available).
EOF_HELP
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  show_help
  exit 0
fi

if [[ "${1:-}" == "--lutris-setup" ]]; then
  shift
  if command -v lug-helper >/dev/null 2>&1; then
    exec lug-helper setup "$@"
  fi
  echo "lug-helper not found. Enable gaming.lutrisRsi to install it." >&2
  exit 1
fi

if command -v rsi-launcher >/dev/null 2>&1; then
  exec rsi-launcher "$@"
fi

cat <<'EOF_MSG' >&2
rsi-launcher not found.
- Enable gaming.lutrisRsi in the install answers (or install nix-citizen).
- Then rebuild and run this script again.
EOF_MSG
exit 1
