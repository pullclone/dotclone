#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/upgrade.sh [--apply|--dry-run] [--force]

Update flake inputs and run upgrade validation gates.

Options:
  --apply    Apply input updates (runs `nix flake update`).
  --force    Continue even when the git working tree is dirty.
  --dry-run  Non-mutating mode; print commands without executing.
  -h, --help Show this help.

Examples:
  scripts/upgrade.sh --dry-run
  scripts/upgrade.sh --apply
  scripts/upgrade.sh --apply --force
EOF
}

force=false
dry_run=false
apply=false

while (($# > 0)); do
  case "$1" in
    --apply)
      apply=true
      ;;
    --force)
      force=true
      ;;
    --dry-run)
      dry_run=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "This script must be run from inside a git repository." >&2
  exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "${repo_root}"

if [[ "${dry_run}" == "true" ]] && [[ "${apply}" == "true" ]]; then
  echo "--dry-run overrides --apply"
  apply=false
fi

echo "==> Git status"
git status --short --branch

if [[ "${apply}" != "true" ]] && [[ "${dry_run}" != "true" ]]; then
  echo "Refusing to mutate flake.lock without --apply" >&2
  usage >&2
  echo "Use one of:" >&2
  echo "  scripts/upgrade.sh --dry-run" >&2
  echo "  scripts/upgrade.sh --apply" >&2
  exit 2
fi

if [[ -n "$(git status --porcelain)" ]] && [[ "${force}" != "true" ]]; then
  echo "Refusing to run on a dirty working tree." >&2
  echo "Commit or stash changes first, or rerun with --force." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]] && [[ "${force}" == "true" ]]; then
  echo "WARNING: continuing on a dirty tree due to --force."
fi

run_cmd() {
  if [[ "${dry_run}" == "true" ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

if [[ "${apply}" == "true" ]]; then
  echo "==> Updating flake inputs"
  run_cmd nix flake update
else
  echo "==> Skipping flake input update (non-mutating mode)"
fi

echo "==> Running quality gates in pinned toolchain"
run_cmd nix develop -c just audit
run_cmd nix develop -c just test-strict
run_cmd nix develop -c nix flake check .

echo "==> flake.lock diff summary"
if [[ "${dry_run}" == "true" ]]; then
  echo "[dry-run] git diff --stat flake.lock"
else
  git diff --stat flake.lock || true
fi

cat <<'EOF'

Reminder: review state version implications before committing upgrades.
- system.stateVersion
- home.stateVersion

Commit lockfile updates intentionally. This script never auto-commits or auto-pushes.
EOF
