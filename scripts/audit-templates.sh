#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

echo "==> templates: nix flake check"
nix flake check ./templates/research

echo "==> templates: smoke run exp001"
nix run ./templates/research#run -- exp001

if command -v shellcheck >/dev/null 2>&1; then
  echo "==> templates: shellcheck scripts"
  shellcheck templates/research/scripts/*.sh
else
  echo "shellcheck not found; skipping template script lint" >&2
fi

echo "Templates audit OK"
