# NyxOS Agent Guide

This guide consolidates the previous `AGENTS.md` and `.agent-instructions.md`.
It is the single source of truth for agent workflow, testing, and output
expectations.

## Purpose

NyxOS provides two reproducible, declarative system profiles built on NixOS:

- Desktop profile: Wayland, gaming, productivity; optimized for interactive UX.
- Server profile: minimal headless config for containers and remote management.

Both profiles share the same core principles: determinism, modularity, and
documentation.

## Repository overview

The repository is domain-oriented. See `docs/CONFIG_MAP.md` for the detailed
map. At a high level:

- `configuration.nix`: system policy orchestrator (services, users, packages)
- `flake.nix`: flake entry point and module wiring
- `hardware-configuration.nix`: generated hardware config (read-only)
- `modules/`: domain modules (boot, core, hardware, programs, tuning, home)
- `profiles/`: system and ZRAM profile composition
- `scripts/`: audit, lint, and maintenance helpers

## Tandem Development: main + variant/with-sudo (Worktree Strategy)

We develop on **both** `main` and `variant/with-sudo` concurrently using **git worktree**.

### Rationale
- Prevent drift between branches.
- Avoid cherry-pick-only workflows and reduce conflict churn.
- Ensure CI/audit parity across both branches.

### Required Setup
Create two worktrees from an existing clone:

```bash
git fetch origin
git worktree prune

mkdir -p ../dotclone-wt
git worktree add ../dotclone-wt/main main
git worktree add ../dotclone-wt/with-sudo variant/with-sudo

git worktree list
```

### Patch Scope Rules

Every change MUST declare scope:

* **[both]** apply to both branches
* **[main only]** apply only to `main`
* **[with-sudo only]** apply only to `variant/with-sudo`

If scope is not declared, assume **[both]**.

### Verification Rules

After implementing any change, run at minimum in BOTH worktrees:

```bash
nix develop --command just audit
```

If additional checks are part of the repo’s standard workflow (flake checks/builds, etc.), run them on BOTH branches as well.

### Branch Divergence Policy

Branch-specific behavior is allowed only when it is intentional and documented (e.g., sudo behavior).
Any divergence must be explained in the patch notes / commit message.

## Branch Topology (Long-Lived Variants)

This repository intentionally maintains **two long-lived variants** in parallel:

- **`main` (default)**: the baseline configuration. This branch intentionally omits `sudo`/root-oriented tooling as a design choice.
- **`variant/with-sudo`**: a supported alternative configuration where `sudo` is available as an explicit feature path.

### Important: this is not a feature branch

`variant/with-sudo` is **not** intended to be merged into `main`. It exists as a persistent, concurrently developed option.

### Sharing changes between variants

When a change should exist in both variants, port it **intentionally**:
- Prefer **cherry-picking** specific commits between branches, or
- Re-apply the change manually when the surrounding context differs.

Avoid “merge the variant into main” workflows; that defeats the purpose of keeping the two variants meaningfully distinct.

### How to land changes (GitHub merge policy)

Repository protections enforce PR-based merges into `main` and `variant/with-sudo`, and only **squash** or **rebase** merges are allowed (no merge commits).

**Default:** use **Squash and merge** for most PRs (clean history, one commit per change).  
**Use Rebase and merge** only when you intentionally want to preserve a linear sequence of meaningful commits.

## Protected branches: PR-first workflow (agent-safe)

`main` and `variant/with-sudo` are protected (PR-only). **Do not commit on protected branches and then try to push.**

### Correct workflow

1. Start from an up-to-date protected base:
   - `git switch main && git pull --ff-only`
   - or `git switch variant/with-sudo && git pull --ff-only`

2. Create a feature branch **before** committing:
   - `git switch -c <type>/<topic>-main`
   - `git switch -c <type>/<topic>-with-sudo` (when targeting the variant)

3. Commit on the feature branch and push:
   - `git push -u origin <branch>`

4. Open a PR with `gh`:
   - `gh pr create --base <base> --head <branch> ...`

5. Merge using **Squash** (default) or **Rebase** (only if preserving meaningful commit sequences).

### Naming conventions

- Use `feat/`, `fix/`, `docs/`, `chore/` prefixes.
- Keep branch names short, kebab-case, and topic-driven.
- Do **not** include batch numbers (e.g., avoid `batch-*`); they add noise and do not reflect repo conventions.

## Upgrade tooling safety: validation vs. mutation

`just upgrade` and `scripts/upgrade.sh` are **intentional mutation tools**. They update inputs and may modify `flake.lock`.

They must **never** be run as part of routine validation, review, or PR preparation.
Avoid backticks in shell-evaluated command strings (for example, anything run via `bash -lc`).
When using `gh pr create --body` via `bash -lc`, use plain text or escaped backticks.

### Validation commands (non-mutating)

During review and CI parity checks, agents must restrict themselves to:

- `just audit`
- `just test-strict`
- `nix flake check .`

These commands must not modify `flake.lock`.

### Upgrade commands (maintainer-only, opt-in)

Only run upgrade tooling when you explicitly intend to update inputs:

- `just upgrade`
- `scripts/upgrade.sh`

Before running upgrade commands:

1. Ensure the working tree is clean.
2. Expect `flake.lock` changes.
3. Review diffs manually.
4. Commit lockfile updates intentionally.

Accidental lockfile mutation during validation is considered a workflow error.

## Golden rules

1. Deterministic and pure: use flakes (`nix flake check .`, `nix build .#...`),
   avoid impure operations (`nix-shell -p`, `nix-env -i`).
2. Domain isolation: hardware owns kernel params; tuning owns sysctl; boot owns
   bootloader configuration.
3. Facts vs policy: install answers live in `modules/core/install-answers.nix`.
4. Boot exclusivity: enable exactly one boot profile via `my.boot` options.
5. Documentation first: update `docs/CONFIG_MAP.md` and `docs/ASSERTIONS.md`
   for non-trivial changes.
6. Test coverage: add assertions and verification for new modules/services.
7. Avoid hardcoded paths: prefer Nix abstractions (`pkgs.*`, `config.*`).
8. No unpinned dependencies: everything must be in `flake.nix` and `flake.lock`.

## Build and audit workflow

- Always use flakes; default host is `nyx` (override with `SYSTEM=...`).
- `just audit` runs `nixfmt-tree --check`, flake check/build, contract
  enforcement, and shellcheck strict/advisory.
- `just ci` runs audit + build + smoke tests; it should pass before PRs.
- Use `nix develop .#agent` for the pinned toolchain.

## Change protocol

Pre-change:
- Run `just bootstrap` to verify required tooling.
- Run `just audit` (or `just check-nixfmt` + `just shellcheck-strict`).

During change:
- Keep commits small and atomic.
- Follow the commit format below.
- Keep modules isolated and honor domain ownership constraints.

Post-change:
- Run `just ci` (lint + build + smoke tests).
- Update docs and assertions as needed.

## Constraints

- Do not edit `hardware-configuration.nix` unless explicitly requested.
- Only `modules/tuning/sysctl.nix` (or ZRAM overrides) may set
  `boot.kernel.sysctl`.
- Only boot/hardware modules may set `boot.kernelParams`.
- Select exactly one `systemProfile` (see `profiles/`).
- Ensure module imports remain a DAG (no circular imports).

## Commit and branch conventions

Commit messages use Conventional Commits:

```
<type>(<scope>): <short description>

<details>
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`.
Scopes are domain-oriented (`boot`, `hardware`, `tuning`, `home`, `flakes`, etc.).

Branch naming:
- `feat/<topic>` for new features
- `fix/<issue>` for fixes
- `docs/<topic>` for documentation work

## Pull request requirements

- Title and description describing what/why/how.
- Checklist in PR body:
  - [ ] `just ci` passes locally
  - [ ] `docs/CONFIG_MAP.md` updated (if structure changed)
  - [ ] `docs/ASSERTIONS.md` updated (if invariants changed)
  - [ ] Tests/smoke checks updated or added
- Apply appropriate labels (`feat`, `fix`, `docs`).

## Testing strategy

1. Lint: `just lint`
2. Build: `just build` or `nix flake check .`
3. Smoke: `just test` (critical binaries, boot profile, maintenance)
4. Integration: scripts under `scripts/` or VM-based checks
5. Runtime: boot and login validation in a VM/staging system

## Documentation standards

Update docs when:
- Adding modules or moving files (`docs/CONFIG_MAP.md`).
- Adding or changing assertions (`docs/ASSERTIONS.md`).
- Changing behavior (update relevant docs).

Formatting:
- GitHub Flavored Markdown
- Use fenced code blocks with language tags where helpful
- Avoid large tables unless necessary

## Troubleshooting (common issues)

- Flake evaluation failure: run `nix flake check .` and fix syntax/inputs.
- Module import error: check paths and ensure imports form a DAG.
- Build failure: inspect `nix log`, check overlay/package changes.
- Smoke test failure: verify related module enablement and assertions.
- Runtime service failure: use `systemctl status <service>` and module configs.

## Required response format

When submitting work, include:

1. Action Summary
2. Files Modified
3. Validation Results
4. Next Steps

Validation Results may be reported as `PASS`, `PASS (with warnings)`, or `FAIL`.

## Workflow checklist

Before starting:
- Read this guide and `docs/CONFIG_MAP.md`.
- Review `docs/ASSERTIONS.md` for invariants.
- Run `just bootstrap`.

During work:
- Follow lint -> build -> test -> document.
- Make atomic commits.

Before submitting:
- Run `just ci`.
- Run `nix develop --command just fmt` before pushing.
- Update `docs/CONFIG_MAP.md` and `docs/ASSERTIONS.md` as needed.
- Prepare PR description and checklist.

After submission:
- Monitor CI and address failures.
- Respond to review feedback.
- Verify changes in a production-like environment when appropriate.
