#!/usr/bin/env bash
set -euo pipefail
# Run gitleaks via nix run to avoid external dependency
gitleaks_config="$(nix path-info nixpkgs#gitleaks)/etc/gitleaks.toml"
if nix run .#gitleaks -- --version >/dev/null 2>&1; then
  nix run .#gitleaks -- detect --config "$gitleaks_config" --no-git --redact --source . --exit-code 1
else
  nix run nixpkgs#gitleaks -- detect --config "$gitleaks_config" --no-git --redact --source . --exit-code 1
fi
