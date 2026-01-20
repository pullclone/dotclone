# Lint & Format Policy

This repository enforces **Nix formatting** and treats other static
analysis as **advisory**.

## Gates

- **Gating:** `nix fmt .` (invoked via `just check-nixfmt` and `just audit`)
  must produce no diff. CI enforces this gate.
- **Advisory:** `statix` and `deadnix` run via `just lint-nix-report`
  and write reports to `reports/{statix,deadnix}.txt` without failing
  the build.

## Suppression Conventions

- **Unused Nix args:** prefix with `_` (e.g., `{ _lib, pkgs, ... }:`) to
  acknowledge intentional unused parameters.
- **Shellcheck:** disable narrowly and locally, e.g.
  `# shellcheck disable=SC2086` immediately above the relevant line.

## Commands

- `just check-nixfmt` — run `nix fmt .` and fail if it changes files.
- `just lint-nix-report` — generate statix/deadnix advisory reports in
  `reports/`.
- `just audit` — formatting gate + full audit (flake check/build + contract checks).
