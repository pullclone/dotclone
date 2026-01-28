#!/usr/bin/env bash
set -euo pipefail

required=(
  "docs/README.md"
  "docs/AGENTS.md"
  "docs/SECURITY_AND_RECOVERY.md"
  "docs/PREFLIGHT.md"
)

missing=()
for path in "${required[@]}"; do
  if [ ! -f "$path" ]; then
    missing+=("$path")
  fi
done

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Missing required docs:" >&2
  printf ' - %s\n' "${missing[@]}" >&2
  exit 1
fi

echo "Docs check OK"
