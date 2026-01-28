# Lint & Format Policy

This repository enforces **Nix formatting** and **ShellCheck** on
critical scripts; other static analysis is **advisory**.

## Gates

- **Gating (format):** `nixfmt-tree --check .` (invoked via
  `just check-nixfmt` and `just audit`) must produce no diff. CI enforces
  this gate.
- **Gating (shell):** `just shellcheck-strict` enforces ShellCheck on
  audit/pre-install scripts.
- **Advisory:** `statix` and `deadnix` run via `just lint-nix-report`
  and write reports to `reports/{statix,deadnix}.txt` without failing
  the build.
- **Advisory (shell):** `just shellcheck-advisory` reports on all
  `scripts/*.sh` without failing the build.

## Suppression Conventions

- **Unused Nix args:** prefix with `_` (e.g., `{ _lib, pkgs, ... }:`) to
  acknowledge intentional unused parameters.
- **Shellcheck:** disable narrowly and locally with a one-line
  rationale, e.g. `# shellcheck disable=SC2086 # intentional word
  splitting`.

## Commands

- `just check-nixfmt` — run `nixfmt-tree --check .` and fail if it
  changes files.
- `just shellcheck-strict` — run gating ShellCheck on critical scripts.
- `just shellcheck-advisory` — run non-gating ShellCheck on all scripts.
- `just lint-nix-report` — generate statix/deadnix advisory reports in
  `reports/`.
- `just audit` — formatting gate + full audit (flake check/build +
  contract checks + shellcheck tiers).
