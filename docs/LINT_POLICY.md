# NyxOS Lint & Format Policy

This repository uses a strict formatting gate plus advisory Nix lint
reports to keep changes reproducible and reviewable.

## Gates (fail the build)

- **Nix formatting**: `nix fmt .` (nixfmt-rfc-style) is enforced via
  `just check-nixfmt` and `just audit`. CI runs the same gate.
- **Shell lint**: `just lint-shell` (shellcheck) covers
  `install-nyxos.sh` and `scripts/**/*.sh`.

## Advisory (reports only)

- **Statix**: `just lint-nix-report` writes `reports/statix.txt` but
  does not fail CI.
- **Deadnix**: `just lint-nix-report` writes `reports/deadnix.txt` but
  does not fail CI.

## Suppression Conventions

- **Nix (deadnix/statix)**: prefer `_unused` for intentional bindings,
  or targeted comments like `# deadnix: allow` / `# statix: ignore` on
  the specific line. Avoid file-wide disables.
- **Shell (shellcheck)**: use narrow disables on the preceding line:
  `# shellcheck disable=SCXXXX` with a short rationale if the rule is
  non-obvious.

## Recommended Workflow

1. `just fmt-nix`
2. `just lint-shell`
3. `just lint-nix-report` (review reports)
4. `just audit` before pushing
