# Lint & Format Policy

NyxOS enforces reproducible formatting and treats static analysis as
advisory. This page documents what is enforced, what is informational,
and how to suppress responsibly.

## Enforced

- **Nix formatting:** `nix fmt .` via `just check-nixfmt` (runs inside
  `just audit`). Any formatter changes must be committed.
- **Shell hygiene:** `shellcheck` over `install-nyxos.sh` and
  `scripts/**/*.sh` inside `just audit`.
- **Flake/build contracts:** `nix flake check .` plus repo contracts in
  `scripts/audit-repo.sh` (hash requirements, forbidden fetchGit,
  centralized sysctl, install-answers scope).

## Advisory

- **Statix + Deadnix:** Run with `just lint-nix-report`. Reports are
  written to `reports/statix.txt` and `reports/deadnix.txt` but do not
  fail CI.
- **Shell formatting:** `just fmt-shell` is available; not a gate.

## Suppression guidance

- **Unused module args:** prefix with `_` (e.g., `{ lib, _config, ... }`)
  to silence `deadnix`.
- **Shellcheck:** add targeted disables, e.g.,
  `# shellcheck disable=SC2086` immediately above the relevant line, and
  only with a short justification in code comments if non-obvious.

## How to run locally

```bash
just audit            # formatting gate + flake check + contracts + shellcheck
just lint-nix-report  # advisory statix/deadnix reports
just fmt-nix          # run the formatter
```

If any enforced gate changes files, commit the formatting before
submitting. The audit gate must pass prior to CI or review.
