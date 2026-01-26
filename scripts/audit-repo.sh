#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

SYSTEM="${SYSTEM:-nyx}"

rg_nix() {
  rg --glob "*.nix" --glob "!templates/**" "$@"
}

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
install_refs="$(rg_nix "/etc/nixos/nyxos-install.nix" --files-with-matches || true)"
if [ -n "$install_refs" ]; then
  mapfile -t install_offenders < <(printf "%s\n" "$install_refs" | grep -v '^modules/core/install-answers.nix$' || true)
  if [ "${#install_offenders[@]}" -gt 0 ]; then
    echo "Found nyxos-install.nix reference outside modules/core/install-answers.nix:"
    printf ' - %s\n' "${install_offenders[@]}"
    exit 1
  fi
fi

echo "==> contract: boot.kernel.sysctl centralized"
sysctl_matches="$(rg_nix "boot\\.kernel\\.sysctl" --files-with-matches || true)"
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
if rg_nix "builtins\\.fetchGit" >/dev/null; then
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
done < <(rg_nix -l "fetch(Tarball|zip)" || true)

echo "==> contract: fetchgit must be hashed"
while IFS= read -r f; do
  if ! rg -q "hash\\s*=" "$f" && ! rg -q "sha256\\s*=" "$f"; then
    echo "Missing hash for fetchgit in $f"
    missing_hash=true
  fi
done < <(rg_nix -l "fetchgit" || true)

if [ "$missing_hash" = true ]; then
  exit 1
fi

echo "==> contract: Niri single-owner checks"
mapfile -t niri_package_files < <(rg_nix -l "programs\\.niri\\.package" || true)
if [ "${#niri_package_files[@]}" -gt 1 ]; then
  echo "programs.niri.package should be owned by one place; found in:"
  printf ' - %s\n' "${niri_package_files[@]}"
  exit 1
fi
mapfile -t niri_config_files < <(rg_nix -l "programs\\.niri\\.(config|finalConfig)" || true)
if [ "${#niri_config_files[@]}" -gt 1 ]; then
  echo "programs.niri.config/finalConfig should be owned by one place; found in:"
  printf ' - %s\n' "${niri_config_files[@]}"
  exit 1
fi
mapfile -t niri_settings_files < <(rg_nix -l "programs\\.niri\\.settings" || true)
mapfile -t niri_enabled_files < <(rg_nix -l "programs\\.niri\\.enable\\s*=\\s*true" || true)
if [ "${#niri_settings_files[@]}" -gt 1 ]; then
  echo "programs.niri.settings should be owned by one place; found in:"
  printf ' - %s\n' "${niri_settings_files[@]}"
  exit 1
fi
if [ "${#niri_enabled_files[@]}" -gt 0 ] && [ "${#niri_settings_files[@]}" -eq 0 ]; then
  echo "programs.niri.settings missing but Niri is enabled:"
  printf ' enablement found in:\n'
  printf ' - %s\n' "${niri_enabled_files[@]}"
  exit 1
fi

echo "==> contract: Noctalia ownership and compatibility"
mapfile -t noctalia_service_files < <(rg_nix -l "services\\.noctalia-shell\\.enable" || true)
mapfile -t noctalia_systemd_files < <(rg_nix -l "programs\\.noctalia-shell" || true)
if [ "${#noctalia_service_files[@]}" -gt 0 ] && [ "${#noctalia_systemd_files[@]}" -gt 0 ]; then
  echo "Noctalia enablement detected via both services.noctalia-shell.enable and programs.noctalia-shell.systemd.enable:"
  printf ' services: %s\n' "${noctalia_service_files[@]}"
  printf ' programs: %s\n' "${noctalia_systemd_files[@]}"
  exit 1
fi
if [ "${#noctalia_service_files[@]}" -eq 0 ] && [ "${#noctalia_systemd_files[@]}" -eq 0 ]; then
  echo "Noctalia enablement missing; expected exactly one service path (prefer programs.noctalia-shell.systemd.enable)"
  exit 1
fi

mapfile -t noctalia_imports < <(rg_nix -l "noctalia\\.homeModules\\.default" || true)
if [ "${#noctalia_imports[@]}" -ne 1 ]; then
  echo "Expected exactly one import of noctalia.homeModules.default; found ${#noctalia_imports[@]}:"
  printf ' - %s\n' "${noctalia_imports[@]}"
  exit 1
fi

mapfile -t noctalia_option_files < <(rg_nix -l "options\\.programs\\.noctalia-shell" || true)
if [ "${#noctalia_option_files[@]}" -gt 0 ]; then
  echo "Noctalia stub option detected (options.programs.noctalia-shell should not exist):"
  printf ' - %s\n' "${noctalia_option_files[@]}"
  exit 1
fi

mapfile -t noctalia_pkg_refs < <(rg_nix -l "pkgsUnstable\\.noctalia-shell" || true)
if [ "${#noctalia_pkg_refs[@]}" -gt 0 ]; then
  echo "WARNING: pkgsUnstable.noctalia-shell referenced (ensure this is documented/justified):"
  printf ' - %s\n' "${noctalia_pkg_refs[@]}"
fi

echo "==> contract: forbid plaintext key material in repo"
mapfile -t key_files < <(rg --files -g "*.key" -g "*.pem" -g "*.p12" -g "*.pfx" -g "*.der" -g "*.csr" --glob "!templates/**" || true)
if [ "${#key_files[@]}" -gt 0 ]; then
  echo "Plaintext key material detected (remove from repo):"
  printf ' - %s\n' "${key_files[@]}"
  exit 1
fi

echo "==> contract: forbid /nix/store key material references"
if rg_nix "/nix/store/[^\"']*\\.(key|pem|p12|pfx|der|csr)" >/dev/null; then
  echo "Key material must not be referenced from /nix/store"
  exit 1
fi
if rg_nix "key(File|file)\\s*=\\s*\\\"/nix/store" >/dev/null; then
  echo "keyFile must not reference /nix/store"
  exit 1
fi

echo "==> shellcheck installer + scripts"
mapfile -t shell_scripts < <(/usr/bin/find install-nyxos.sh scripts -type f -name "*.sh")
if [ "${#shell_scripts[@]}" -gt 0 ]; then
  shellcheck "${shell_scripts[@]}"
fi

echo "Audit OK"
