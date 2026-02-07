#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# Resolve gitleaks from the repo flake so CI/local both use pinned inputs.
gitleaks_out="$(nix build --no-link --print-out-paths .#gitleaks)"
gitleaks_bin="$gitleaks_out/bin/gitleaks"

if [ ! -x "$gitleaks_bin" ]; then
  echo "secrets-scan: gitleaks binary not found at $gitleaks_bin" >&2
  echo "secrets-scan: flake-pinned package out path was $gitleaks_out" >&2
  exit 1
fi

echo "secrets-scan: using gitleaks package path: $gitleaks_out"
echo "secrets-scan: using gitleaks default config resolution"

"$gitleaks_bin" detect \
  --no-git \
  --redact \
  --source . \
  --exit-code 1
