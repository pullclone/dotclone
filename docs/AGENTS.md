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
- Update `docs/CONFIG_MAP.md` and `docs/ASSERTIONS.md` as needed.
- Prepare PR description and checklist.

After submission:
- Monitor CI and address failures.
- Respond to review feedback.
- Verify changes in a production-like environment when appropriate.
