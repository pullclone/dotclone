# Preflight Guide

This document explains what `just audit` checks and how to interpret failures.

## What `just audit` runs

- `just check-nixfmt`: `nixfmt-tree --check .` must report no changes.
- `just shellcheck-strict`: strict shellcheck on critical scripts
  (audit/pre-install/preflight).
- `scripts/audit-repo.sh`: contract checks for the flake and repo layout.
- `scripts/check-docs.sh`: required documentation presence (gating).
- `just shellcheck-advisory`: non-blocking shellcheck across all scripts.

## What `scripts/audit-repo.sh` enforces

- `/etc/nixos/nyxos-install.nix` only referenced in
  `modules/core/install-answers.nix`.
- `boot.kernel.sysctl` defined only in `modules/tuning/sysctl.nix` or
  approved ZRAM/system profiles.
- `builtins.fetchGit` is forbidden.
- `fetchTarball`/`fetchzip`/`fetchgit` must include a hash.
- Niri and Noctalia ownership rules are respected.
- No plaintext key material in the repo.
- No `/nix/store` key material references.

## Formatting expectations

- Nix formatting is enforced with `nixfmt-tree`.
- Use `just fmt-nix` to format, `just check-nixfmt` to verify.

## ShellCheck policy

- Strict (gating): audit/preflight/pre-install scripts.
- Advisory (non-blocking): all `scripts/*.sh`.
- Suppressions must be local with a one-line rationale.
