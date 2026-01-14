#!/usr/bin/env bash
set -euo pipefail

echo "==> nix flake check"
nix flake check .

echo "==> build default config"
nix build ".#nixosConfigurations.nyx.config.system.build.toplevel"

echo "==> contract: /etc/nixos/nyxos-install.nix only in install-answers"
if rg "/etc/nixos/nyxos-install.nix" --glob "*.nix" | grep -v "modules/core/install-answers.nix"; then
  echo "Found disallowed nyxos-install.nix reference outside modules/core/install-answers.nix"
  exit 1
fi

echo "==> contract: boot.kernel.sysctl only in modules/tuning/sysctl.nix"
if rg "boot\\.kernel\\.sysctl" --glob "*.nix" | grep -v "modules/tuning/sysctl.nix"; then
  echo "Found boot.kernel.sysctl outside modules/tuning/sysctl.nix"
  exit 1
fi

echo "==> contract: forbid builtins.fetchGit"
if rg "builtins\\.fetchGit" --glob "*.nix"; then
  echo "builtins.fetchGit is forbidden"
  exit 1
fi

echo "==> shellcheck installer + scripts"
shellcheck install-nyxos.sh scripts/**/*.sh

echo "Audit OK"
