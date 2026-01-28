# NyxOS Agent Guidelines

This document serves as an overview and operational guide for
contributors working on the NyxOS NixOS configuration. It explains
**why** the repository exists, **how** it is structured, and the
**rules** agents should follow when making changes. A more detailed,
step‑by‑step orientation is provided in `.agent-instructions.md`.

## Purpose

NyxOS provides two reproducible, declarative system profiles built on
NixOS:

- **Desktop Profile** -- A full‑featured desktop environment with
  Wayland, gaming support, and productivity tools. It prioritizes
  interactive performance and user experience.
- **Server Profile** -- A minimal, headless configuration optimized for
  containerized workloads and remote management. It favors stability,
  security, and low overhead.

Both profiles share a common core and follow the same design principles:
**determinism**, **modularity**, and **documentation**.

## Repository Overview

The repository is organized according to **domains**. Each directory
encapsulates a self‑contained slice of functionality:

    
    ├── configuration.nix      # System policy orchestrator (services, users, packages)
    ├── flake.nix              # Flake entry point & module wiring
    ├── flake.lock             # Pinned versions of all dependencies
    ├── hardware-configuration.nix  # Auto‑generated hardware config (read‑only)
    ├── install-nyxos.sh       # Installer script (writes nyxos-install.nix answers)
    ├── pkgs/                  # Custom derivations (e.g., LatencyFleX)
    ├── scripts/               # Maintenance & test scripts (audit, lint helpers)
    └── modules/               # Domain‑driven NixOS modules
        ├── boot/              # Bootloader & Secure Boot logic
        ├── core/              # Installation facts & answers
        ├── hardware/          # Hardware‑specific modules (e.g., AMD GPU)
        ├── programs/          # System program toggles (e.g., LatencyFleX)
        ├── tuning/            # Kernel & performance tuning (sysctl, zram)
        └── home/              # Home Manager configuration (apps, panels, shells)

See `docs/CONFIG_MAP.md` for a detailed breakdown of files and their
roles.

## Golden Rules

1.  **Deterministic & Pure** -- All builds must be reproducible. Use Nix
    flakes (`nix flake check .`, `nix build .#…`), pinned dependencies
    (`flake.lock`), and avoid any impure operations (no `nix-shell -p`
    or `nix-env -i`).
2.  **Domain Isolation** -- Keep modules self‑contained. Do not define
    global state in random files. Hardware modules own hardware
    parameters; tuning modules own sysctl; boot modules own bootloader
    configuration.
3.  **Facts vs Policy** -- Installation answers (hostname, timezone,
    username, MAC) live in `modules/core/install-answers.nix` and are
    considered **facts**. Policy lives in `configuration.nix` and
    modules. Do not hardcode these values.
4.  **Boot Exclusivity** -- Exactly one boot profile (UKI or Secure
    Boot) may be enabled via `my.boot` options. Modules enforce this; do
    not circumvent.
5.  **Documentation First** -- Any non‑trivial change must update both
    `docs/CONFIG_MAP.md` and `docs/ASSERTIONS.md` to reflect the new
    structure and runtime invariants.
6.  **Test Coverage** -- New modules, services or tunings require
    corresponding assertions and verification steps. At minimum, update
    smoke tests and add runtime checks where appropriate.
7.  **Avoid Hardcoded Paths** -- Use Nix abstractions (`pkgs.*`,
    `config.*`) instead of absolute paths. Do not import or reference
    files outside the repository structure.
8.  **No Unpinned Dependencies** -- All inputs must be defined in
    `flake.nix` and locked in `flake.lock`.

## Build Truth

- **Flake‑Based** -- Always build via flakes: `nix flake check .` to
  test, `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
  to build.
- **Audit Gate** -- `just audit` (runs `nixfmt-tree --check`, flake
  check, contract greps, and shellcheck strict/advisory) is the
  preferred pre-push workflow; CI enforces the same formatting gate.
- **Default System** -- The canonical host is `nyx`. This can be
  overridden by setting the `SYSTEM` environment variable, but changes
  must still pass CI for `nyx`.
- **CI Pipeline** -- Use the `just` tasks defined in the repository
  (`just ci` ≡ lint + build + smoke tests). The pipeline runs
  automatically via GitHub Actions and must succeed before changes are
  merged.

## Agent Workflow Rules

### Change Protocol

1.  **Bootstrap** -- Run `just bootstrap` to install and verify required
    tools (Nix, direnv, etc.).
2.  **Lint/Format** -- Run `just audit` (or `just check-nixfmt` +
    `just shellcheck-strict`) to enforce nixfmt-tree and critical
    shellcheck gates. For advisory Nix lint, use `just lint-nix-report`.
3.  **Build** -- Run `just build` or `nix build .#nixosConfigurations.nyx.config.system.build.toplevel`
    to ensure that the configuration evaluates and builds successfully.
4.  **Test** -- Run `just test` and, where appropriate, the scripts
    under `scripts/` to validate runtime expectations (e.g., Btrfs
    maintenance, service status).
5.  **Document** -- Update `docs/CONFIG_MAP.md` and `docs/ASSERTIONS.md`
    to reflect your changes and introduce any new assertions. If adding
    or modifying modules, include them in the documentation.

### Constraints

- **Read‑Only Hardware Config** -- Never edit
  `hardware-configuration.nix` unless specifically instructed.
- **Sysctl Centralization** -- Do not set `boot.kernel.sysctl` anywhere
  except in `modules/tuning/sysctl.nix` or via overrides within ZRAM
  modules.
- **Boot Parameters** -- Only the boot profile or hardware modules may
  set `boot.kernelParams`.
- **System/ZRAM Profiles** -- Select exactly one system profile via the
  flake argument `systemProfile` (profiles live under `profiles/` and
  include ZRAM + tuning). Do not import multiple profiles or add ad-hoc
  ZRAM modules. Official profiles:
  `latency|balanced|throughput|battery|memory-saver`. Only the 10
  realized configs (`nyx-<profile>-lfx-{on,off}`) plus alias `nyx` are
  supported.
- **No Circular Imports** -- Ensure module imports form a directed
  acyclic graph (DAG).

## Testing Expectations

Agents are responsible for ensuring changes do not break existing
functionality. The following phases should be covered:

- **Lint Phase** -- `shellcheck`, `shfmt`, and static checks must pass
  via `just lint`.
- **Build Phase** -- The flake must evaluate and build for the default
  system (`nyx`). Use `nix flake check .` and `just build`.
- **Smoke Tests** -- `just test` must verify that critical binaries
  exist (`rocminfo`, `latencyflex.json`, etc.), the correct boot profile
  is selected, and Btrfs maintenance configuration is present.
- **Runtime Tests** -- Where possible, spin up the built system in a VM
  or test environment and ensure that services start, the system boots
  with the chosen bootloader, and the user can log in.

## Required Output Format

When submitting work (via PR comments or ChatGPT agent replies), always
include:

1.  **Action Summary** -- What was done, at a high level.
2.  **Files Modified** -- A list of changed or added files.
3.  **Validation Results** -- Test outputs or build status (e.g.,
    `just ci` log summary).
4.  **Next Steps** -- Any follow‑up work that remains or recommendations
    for reviewers.

## Agent Special Instructions

Detailed, one‑time orientation and workflow guidance is provided in the
file `.agent-instructions.md` (see below). Agents should read it
**before** starting work to understand commit conventions, branch
strategy, PR requirements, and detailed testing procedures.

------------------------------------------------------------------------
