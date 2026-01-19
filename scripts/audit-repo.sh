#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

SYSTEM="${SYSTEM:-nyx}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

require_cmd nix
require_cmd rg
require_cmd shellcheck

echo "==> nix flake check"
nix flake check .

echo "==> build toplevel for SYSTEM=${SYSTEM}"
nix build ".#nixosConfigurations.${SYSTEM}.config.system.build.toplevel"

echo "==> contract: /etc/nixos/nyxos-install.nix only in modules/core/install-answers.nix"
install_refs="$(rg "/etc/nixos/nyxos-install.nix" --glob "*.nix" --files-with-matches || true)"
if [ -n "$install_refs" ]; then
  mapfile -t install_offenders < <(printf "%s\n" "$install_refs" | grep -v '^modules/core/install-answers.nix$' || true)
  if [ "${#install_offenders[@]}" -gt 0 ]; then
    echo "Found nyxos-install.nix reference outside modules/core/install-answers.nix:"
    printf ' - %s\n' "${install_offenders[@]}"
    exit 1
  fi
fi

echo "==> contract: boot.kernel.sysctl centralized"
sysctl_matches="$(rg "boot\\.kernel\\.sysctl" --glob "*.nix" --files-with-matches || true)"
if [ -n "$sysctl_matches" ]; then
  sysctl_offenders=()
  while IFS= read -r file; do
    case "$file" in
      modules/tuning/sysctl.nix) continue ;;
      profiles/zram/*) continue ;;
      profiles/system/*) continue ;;
      *) sysctl_offenders+=("$file") ;;
    esac
  done <<< "$sysctl_matches"

  if [ "${#sysctl_offenders[@]}" -gt 0 ]; then
    echo "Found boot.kernel.sysctl outside the allowed locations:"
    printf ' - %s\n' "${sysctl_offenders[@]}"
    exit 1
  fi
fi

echo "==> contract: forbid builtins.fetchGit"
if rg "builtins\\.fetchGit" --glob "*.nix" >/dev/null; then
  echo "builtins.fetchGit is forbidden"
  exit 1
fi

echo "==> contract: fetchTarball/fetchzip must be hashed"
missing_hash=false
while IFS= read -r f; do
  if ! rg -q "hash\\s*=" "$f" && ! rg -q "sha256\\s*=" "$f"; then
    echo "Missing hash for fetchTarball/fetchzip in $f"
    missing_hash=true
  fi
done < <(rg -l "fetch(Tarball|zip)" --glob "*.nix" || true)

echo "==> contract: fetchgit must be hashed"
while IFS= read -r f; do
  if ! rg -q "hash\\s*=" "$f" && ! rg -q "sha256\\s*=" "$f"; then
    echo "Missing hash for fetchgit in $f"
    missing_hash=true
  fi
done < <(rg -l "fetchgit" --glob "*.nix" || true)

if [ "$missing_hash" = true ]; then
  exit 1
fi

echo "==> shellcheck installer + scripts"
mapfile -t shell_scripts < <(/usr/bin/find install-nyxos.sh scripts -type f -name "*.sh")
if [ "${#shell_scripts[@]}" -gt 0 ]; then
  shellcheck "${shell_scripts[@]}"
fi

echo "Audit OK"
