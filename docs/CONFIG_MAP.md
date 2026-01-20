# NyxOS Configuration Map

This document provides a structured map of the NyxOS repository, showing
where major files and modules live, the build‑time vs runtime boundary,
and quick guides for implementation. It reflects the **domain‑driven**
architecture and the separation of **facts** vs **policy** adopted in
the latest refactor.

## Repository Structure

    
    ├── configuration.nix               # Main system policy orchestrator (services, users, packages)
    ├── flake.lock
    ├── flake.nix                       # Flake entry point & module wiring (rooted here; no ./NixOS)
    ├── hardware-configuration.nix      # Generated hardware config (mounts/filesystems)
    ├── install-nyxos.sh                # Repository-based installer script
    ├── overlays/                       # Overrride, extend + pkgs ensure visibility to 🏠 manager & system
    │   └── latencyflex.nix             # Exposes the locally-packaged LatencyFleX as pkgs.latencyflex
    ├── pkgs/                           # Custom package derivations
    ├── profiles/                       # Flake-native system + ZRAM profile set
    ├── templates/
    │   └── research/                   # Opt-in, standalone research flake (pinned devShell + run app)
    ├── scripts/                        # Maintenance & test scripts
    │   ├── audit-repo.sh               # Contract + flake/build audit
    │   ├── test-configuration.sh       # Static sanity checks against configuration files
    │   └── test-optimizations.sh       # Runtime optimisation checks (optional)
    └── modules/                        # Reusable modules (domain‑driven)
        ├── boot/                       # Bootloader & Secure Boot logic
        │   └── boot-profile.nix        # Switchable profile (UKI vs Lanzaboote/Secure Boot)
        ├── core/                       # Installation facts & data
        │   └── install-answers.nix     # Hostname, timezone, user & MAC answers
        ├── hardware/                   # Hardware-specific configurations
        │   └── amd-gpu.nix             # AMD Strix Point kernel params & ROCm stack
        │   └── nvidia-gpu.nix          # Install-driven NVIDIA/PRIME wiring
        ├── programs/                   # System-level program modules
        │   └── latencyflex-module.nix  # Toggle for the LatencyFleX Vulkan layer
        ├── tuning/                     # Performance & kernel tuning
        │   └── sysctl.nix              # Kernel sysctl, I/O schedulers, Btrfs maintenance
        ├── security/                   # Hardening modules (NTS time sync, systemd NNP, USBGuard)
        └── home/                       # Home Manager configuration
            ├── home-ashy.nix           # HM entry point
            ├── apps/                   # User applications (Brave, Btop, Cava)
            ├── core/                   # Home options definition
            ├── niri/                   # Compositor settings (Niri)
            ├── noctalia/               # Noctalia panel config
            ├── shell/                  # Shell environments (Bash/Fish/Starship)
            ├── terminals/              # Terminal emulators (Kitty)
            └── waybar/                 # Waybar panel config

### Noteworthy Files

- `modules/core/install-answers.nix` -- reads
  `/etc/nixos/nyxos-install.nix` to inject dynamic **facts** (hostName,
  timeZone, userName, MAC) into the system configuration.
  Installs expanded facts (snapshots, trim, trust, boot, swap, profile)
  and exports them via `config.my.install`.
- `modules/boot/boot-profile.nix` -- defines mutually exclusive
  boot profiles (UKI vs Secure Boot via Lanzaboote) and the associated
  assertions.
- `modules/tuning/sysctl.nix` -- the **sole** source for
  `boot.kernel.sysctl` definitions and Btrfs maintenance services.
- `modules/security/phase.nix` -- defines `my.security.phase`,
  `my.security.breakglass`, and `my.security.assertions` toggles for
  sequenced hardening rollouts.
- `modules/security/access.nix` -- applies least-privilege doas rules
  and enforces break-glass gating when `my.security.phase >= 1`.
- `modules/security/time-sync.nix` -- Chrony with NTS defaults; override
  via `my.security.timeSync.ntsServers`.
- `modules/security/systemd-hardening.nix` -- sets
  `DefaultNoNewPrivileges=yes` globally; override per-unit with
  `serviceConfig.NoNewPrivileges = lib.mkForce false`.
- `modules/security/usbguard.nix` -- enables USBGuard with declarative
  `etc/usbguard/rules.conf`.
- `profiles/` -- flake-native system + ZRAM profile modules; the flake
  asserts that `systemProfile` is one of the official profiles and
  yields finite outputs (see below).
- `pkgs/latencyflex.nix` -- custom derivation that installs the
  LatencyFleX implicit layer and its manifest.
- `docs/OPERATIONS.md` -- daily-use cheat sheet covering `nixos-option`,
  build/switch commands, and the end-state checklist.
- `docs/SECURITY_PHASES.md` -- phased hardening map, dry-activate/test
  harness, and break-glass expectations.
- `docs/RECOVERY.md` -- recovery playbook and break-glass procedures for
  failed or staged hardening changes.
- `docs/REPRODUCIBILITY.md` -- release provenance snippet (how to cite
  and reproduce exact builds).
- `templates/research/` -- opt-in, standalone flake for lightweight
  experiments; executable documentation/boilerplate with pinned Python
  devShell, helper scripts, and a sample experiment. Not required for
  system builds.

### Official Profiles & Finite Outputs

- Official profiles: `latency`, `balanced`, `throughput`, `battery`,
  `memory-saver`.
- Realized system outputs (pure, finite): `nyx-<profile>-lfx-<on|off>`
  (10 total) plus alias `nyx` → `nyx-balanced-lfx-on`.
- Build/switch examples:
  - `just build` / `just switch` (env overrides: `SYSTEM_PROFILE`,
    `LATENCYFLEX_ENABLE`)
  - `nix build .#nixosConfigurations.nyx-<profile>-lfx-<on|off>.config.system.build.toplevel`
  - `sudo nixos-rebuild switch --flake .#nyx-<profile>-lfx-<on|off>`

### Build & Lint Workflow (authoritative)

- `nix develop` — enter pinned devShell (just, git, rg, shellcheck,
  shfmt, nixfmt, statix, deadnix).
- `just audit` — runs `nix fmt` gate, `nix flake check .`, contract greps,
  and shellcheck; CI enforces the same gate (templates are excluded).
- `nix fmt .` / `just fmt-nix` — canonical formatter (nixfmt rfc style).
- `just lint-nix-report` — advisory `reports/{statix,deadnix}.txt`
  (never fails).
- `just audit-templates` — opt-in checks for `templates/research/` flake.
- `just lint-shell` / `just fmt-shell` — shellcheck/shfmt for
  `install-nyxos.sh` + `scripts/**/*.sh`.
- `just build` / `just switch` — pure builds against finite configs
  (`nyx-<profile>-lfx-{on,off}`), default `nyx`.

## Build‑Time vs Runtime Boundary
  
### Build-Time Components

- **Flake definition** (`flake.nix`): pins inputs, defines
  outputs, and wires together modules.

- **Install facts** (`modules/core/install-answers.nix`): dynamic facts
  generated during installation (hostname, timezone, username, MAC).

### Install Facts Contract (Authoritative)

Install-time facts are collected once by `install-nyxos.sh` and written to:

- `/etc/nixos/nyxos-install.nix`

These facts are loaded **exactly once** by:

- `modules/core/install-answers.nix`

and are re-exported as a **typed, structured interface** at:

- `config.my.install`

**Rules:**

- No other module may import `nyxos-install.nix` directly
  (including Home Manager modules).
- All system, boot, tuning, snapshot, and trust logic must consume
  install-time decisions exclusively via `config.my.install`.
- This file represents *facts*, not *policy* — interpretation belongs to
  domain modules.

- **Domain modules** (`modules/*`): specialized logic for boot,
  hardware, tuning, and home evaluated during evaluation.
- **System policy** (`configuration.nix`): orchestrates services,
  users, packages and imports domain modules.
- **Home Manager config** (`modules/home/home-ashy.nix`): declares the
  user environment; imported via the flake.
- **Custom packages** (`pkgs/`): local overrides and derivations.

### Runtime Components

- **Bootloader**: systemd‑boot or Lanzaboote, as selected in
  `boot-profile.nix`.
- **Services**: systemd services such as SDDM, NetworkManager, Netdata,
  Prometheus, and Btrfs maintenance declared in `configuration.nix` and
  modules.
- **Wayland compositor**: Niri, configured in `modules/home/niri/`.
- **Panels**: Waybar and/or Noctalia, configured in
  `modules/home/waybar` or `modules/home/noctalia`.
- **System/ZRAM profile**: created by flake-selected profiles under
  `profiles/`.
- **Filesystem maintenance**: periodic defragmentation, balance, scrub
  and TRIM configured in `sysctl.nix`.

## Quick Implementation Guide

### Adding a New Module

1.  **Identify the domain**: decide if the feature belongs to
    `programs`, `hardware`, `tuning`, `home`, or (future)
    `services`/`virtualization`.
2.  **Location**: create the file under `modules/<domain>/` with a
    descriptive name.
3.  **Structure**: follow the existing module pattern
    (`{ config, lib, pkgs, ... }: {...}`), defining your own options via
    `lib.mkOption` or `lib.mkEnableOption` and using `lib.mkIf` to
    conditionally apply config.
4.  **Integration**: import the new module in `flake.nix` (global) or
    `configuration.nix` (policy‑specific). Do not forget to add an
    appropriate assertion in `docs/ASSERTIONS.md` if the module
    introduces new invariants.

### Adding a New Service

1.  **Configuration**: add the service to the `services = { ... }` block
    in `configuration.nix` or encapsulate it in a new module under
    `modules/services/` (recommended for reusability).
2.  **Kernel tuning**: if the service requires kernel parameters or
    sysctl tuning, add them to `modules/tuning/sysctl.nix` rather than
    directly in `configuration.nix`.
3.  **Assertions**: document runtime invariants (e.g., the service must
    reach `active` state) in `docs/ASSERTIONS.md`.

### Adding Home Manager Configuration

1.  **Location**: create a module under `modules/home/<category>/`
    (e.g., `terminals/kitty.nix`).
2.  **Structure**: follow Home Manager conventions, defining options and
    using `lib.mkIf` to handle toggles.
3.  **Integration**: import the module in `modules/home/home-ashy.nix`,
    adding the option or enabling block.
4.  **Testing**: run `nixos-rebuild switch` or
    `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
    and verify that the configuration applies without errors.

## Kernel Tuning Reference

- **Sysctl tuning**: all kernel parameters live in
  `modules/tuning/sysctl.nix`. Do **not** define `boot.kernel.sysctl`
  elsewhere to avoid
  conflicts[\[1\]](https://github.com/pullclone/dotclone/blob/HEAD/modules/tuning/sysctl.nix#L7-L40).
- **Boot parameters**: general boot parameters (e.g., `quiet`, `splash`)
  are defined in the boot profile. Hardware‑specific parameters (e.g.,
  `amd_pstate=active`) live in hardware modules such as
  `modules/hardware/amd-gpu.nix`[\[2\]](https://github.com/pullclone/dotclone/blob/HEAD/modules/hardware/amd-gpu.nix#L7-L10).
- **I/O scheduler**: set via `boot.extraModprobeConfig` in
  `sysctl.nix`[\[3\]](https://github.com/pullclone/dotclone/blob/HEAD/modules/tuning/sysctl.nix#L46-L51).
- **Filesystem maintenance**: `sysctl.nix` defines a one‑shot Btrfs
  optimisation service and periodic maintenance via
  `/etc/btrfs-maintenance.xml`[\[4\]](https://github.com/pullclone/dotclone/blob/HEAD/modules/tuning/sysctl.nix#L56-L83).

## Evolving Runtime Component Map

  -------------------------------------------------------------------------------------
  Component       Type            Location                             Responsibility
  --------------- --------------- ------------------------------------ ----------------
  Bootloader      System          `modules/boot/boot-profile.nix`      Switchable UKI
                                                                       or Secure Boot
                                                                       via Lanzaboote

  Install Facts   Config          `modules/core/install-answers.nix`   Hostname,
                                                                       timezone,
                                                                       username, MAC
                                                                       injection

  Hardware        Config          `modules/hardware/amd-gpu.nix`       ROCm packages,
                                                                       AMD kernel
                                                                       params

  Sysctl          Config          `modules/tuning/sysctl.nix`          Kernel sysctl
                                                                       knobs, I/O
                                                                       scheduler, Btrfs
                                                                       tuning
  Snapshots       Service         `modules/tuning/btrfs-snapshots.nix` Btrfs snapshot
                                                                       policy (btrbk)

  System Profile  Module          `profiles/system/`                  System + ZRAM
                                                                       tuning (flake
                                                                       arg driven)

  Waybar          Service         `modules/home/waybar/`               Status bar with
                                                                       dynamic island

  Noctalia        Service         `modules/home/noctalia/`             Alternative
                                                                       panel via
                                                                       upstream HM
                                                                       module

  Niri            Service         `modules/home/niri/`                 Wayland
                                                                       compositor

  LatencyFleX     Package         `pkgs/latencyflex.nix`               Vulkan implicit
                                                                       layer for
                                                                       latency
                                                                       reduction

  Btrfs Maint.    Service         `modules/tuning/sysctl.nix`          Defrag, balance,
                                                                       scrub, trim
                                                                       tasks
  -------------------------------------------------------------------------------------

### Component Relationships

    graph TD
        A[Flake Entry] --> B[Boot Profile]
        A --> C[Install Answers]
        A --> D[Hardware & Tuning Modules]
        A --> E[System Policy (configuration.nix)]
        A --> F[Home Manager]

        C -->|Feeds Facts| E
        D -->|Configures Kernel| E

        E --> G[Services]
        E --> H[System Packages]

        F --> I[Shells]
        F --> J[Desktop (Niri/Waybar/Noctalia)]
        F --> K[Apps]

## Planned Updates (install/trust/snapshot wiring)

- Align boot profile selection with install answers (`boot.mode`) and trust phase (`trust.phase`).
- Derive snapshot services and retention from `my.install.snapshots.*` instead of static defaults.
- Normalize storage trim and encryption intent from the expanded `nyxos-install.nix` schema.

### Installer → Answers → Consumer Map

| Installer prompt                        | Answers file field                        | Consumed by                               |
| --------------------------------------- | ----------------------------------------- | ----------------------------------------- |
| Username                                | `userName`                                | `modules/core/install-answers.nix` → `config.my.install.userName` (users) |
| Hostname                                | `hostName`                                | `modules/core/install-answers.nix` → `networking.hostName`                |
| Timezone                                | `timeZone`                                | `modules/core/install-answers.nix` → `time.timeZone`                     |
| MAC mode/interface/address              | `mac.mode/interface/address`              | `modules/core/install-answers.nix` → NetworkManager policy                |
| Boot mode                               | `boot.mode`                               | `modules/boot/boot-profile.nix` (selects UKI vs Secure Boot; trust.phase gates enforcement) |
| Trust phase                             | `trust.phase`                             | Boot/Secure Boot gating (dev vs enforced; TPM/firmware enforcement deferred until enforced) |
| Snapshot policy (retention/schedule/remote/prePost) | `snapshots.*`                   | Snapshot services (planned: derive enablement/retention)                 |
| Trim policy                             | `storage.trim.*`                          | Storage maintenance (planned: trim scheduling/allowDiscards)             |
| Encryption intent                       | `encryption.mode`                         | Future LUKS wiring (intent signalling)                                   |
| Swap mode/size                          | `swap.mode/sizeGiB`                       | Swap provisioning (partition vs none)                                    |
| System profile                          | `profile.system`                          | Flake arg → system profile selection (already wired)                     |
| Container stack                         | `my.programs.containers.enable`           | `modules/programs/containers.nix` (Podman + Distrobox)                   |

## Change Implementation Flow

1.  **Identify the domain**: does your change belong in system policy
    (`configuration.nix`) or in a specialized domain module
    (`modules/*`)?
2.  **Locate the directory**: use the structure above to place new files
    consistently.
3.  **Follow existing patterns**: copy the structure of similar modules,
    declaring options, using `lib.mkIf`, and merging via `lib.mkMerge`
    as needed.
4.  **Update documentation**: modify this map and `docs/ASSERTIONS.md`
    if the directory structure or invariants change.
5.  **Test**: run `nix flake check .` and build the system to validate
    that paths and syntax are correct.

## Future Component Planning

- **Container runtime** -- Add LXC/Incus or Podman virtualization
  support under `modules/virtualization/`.
- **Gaming layer** -- Steam, Wine, and related tools under
  `modules/programs/gaming.nix`.
- **Backup system** -- Borg, Restic or similar under
  `modules/services/backup.nix` with scheduled tasks.
- **Monitoring** -- Break out Prometheus/Grafana into
  `modules/services/monitoring.nix` for easier reuse.
- **Server profile** -- A separate NixOS configuration for server use
  with a different service mix.

------------------------------------------------------------------------

[\[1\]](https://github.com/pullclone/dotclone/blob/HEAD/modules/tuning/sysctl.nix#L7-L40)
[\[3\]](https://github.com/pullclone/dotclone/blob/HEAD/modules/tuning/sysctl.nix#L46-L51)
[\[4\]](https://github.com/pullclone/dotclone/blob/HEAD/modules/tuning/sysctl.nix#L56-L83)
sysctl.nix

<https://github.com/pullclone/dotclone/blob/HEAD/modules/tuning/sysctl.nix>

[\[2\]](https://github.com/pullclone/dotclone/blob/HEAD/modules/hardware/amd-gpu.nix#L7-L10)
amd-gpu.nix

<https://github.com/pullclone/dotclone/blob/HEAD/modules/hardware/amd-gpu.nix>
