# NyxOS Configuration Map

This document provides a structured map of the NyxOS repository, showing
where major files and modules live, the build‑time vs runtime boundary,
and quick guides for implementation. It reflects the **domain‑driven**
architecture and the separation of **facts** vs **policy** adopted in
the latest refactor.

## Repository Structure

    NixOS/
    ├── configuration.nix               # Main system policy orchestrator (services, users, packages)
    ├── flake.lock
    ├── flake.nix                       # Flake entry point & module wiring
    ├── hardware-configuration.nix      # Generated hardware config (mounts/filesystems)
    ├── install-nyxos.sh                # Repository-based installer script
    ├── overlays/                       # Overrride, extend + pkgs ensure visibility to 🏠 manager & system
    │   └── latencyflex.nix             # Exposes the locally-packaged LatencyFleX as pkgs.latencyflex
    ├── pkgs/                           # Custom package derivations
    │   └── overlay.nix                 # Overlays for third‑party packages
    ├── scripts/                        # Maintenance & test scripts
    │   ├── test-configuration.sh       # Static sanity checks against configuration files
    │   └── test-optimizations.sh       # Runtime optimisation checks (optional)
    └── modules/                        # Reusable modules (domain‑driven)
        ├── boot/                       # Bootloader & Secure Boot logic
        │   └── boot-profile.nix        # Switchable profile (UKI vs Lanzaboote/Secure Boot)
        ├── core/                       # Installation facts & data
        │   └── install-answers.nix     # Hostname, timezone, user & MAC answers
        ├── hardware/                   # Hardware-specific configurations
        │   └── amd-gpu.nix             # AMD Strix Point kernel params & ROCm stack
        ├── programs/                   # System-level program modules
        │   └── latencyflex-module.nix  # Toggle for the LatencyFleX Vulkan layer
        ├── tuning/                     # Performance & kernel tuning
        │   ├── sysctl.nix              # Kernel sysctl, I/O schedulers, Btrfs maintenance
        │   └── zram/                   # ZRAM profiles (lz4, zstd balanced/aggressive, writeback)
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

- `NixOS/modules/core/install-answers.nix` -- reads
  `/etc/nixos/nyxos-install.nix` to inject dynamic **facts** (hostName,
  timeZone, userName, MAC) into the system configuration.
- `NixOS/modules/boot/boot-profile.nix` -- defines mutually exclusive
  boot profiles (UKI vs Secure Boot via Lanzaboote) and the associated
  assertions.
- `NixOS/modules/tuning/sysctl.nix` -- the **sole** source for
  `boot.kernel.sysctl` definitions and Btrfs maintenance services.
- `NixOS/modules/tuning/zram/` -- a collection of ZRAM profiles. Select
  exactly one profile when building.
- `NixOS/pkgs/latencyflex.nix` -- custom derivation that installs the
  LatencyFleX implicit layer and its manifest.

## Build‑Time vs Runtime Boundary

### Build‑Time Components

- **Flake definition** (`NixOS/flake.nix`): pins inputs, defines
  outputs, and wires together modules.
- **Install facts** (`modules/core/install-answers.nix`): dynamic facts
  generated during installation (hostname, timezone, username, MAC).
- **Domain modules** (`modules/*`): specialized logic for boot,
  hardware, tuning, and home evaluated during evaluation.
- **System policy** (`NixOS/configuration.nix`): orchestrates services,
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
- **ZRAM devices**: created by profiles under `modules/tuning/zram/`.
- **Filesystem maintenance**: periodic defragmentation, balance, scrub
  and TRIM configured in `sysctl.nix`.

## Quick Implementation Guide

### Adding a New Module

1.  **Identify the domain**: decide if the feature belongs to
    `programs`, `hardware`, `tuning`, `home`, or (future)
    `services`/`virtualization`.
2.  **Location**: create the file under `NixOS/modules/<domain>/` with a
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
    in `NixOS/configuration.nix` or encapsulate it in a new module under
    `modules/services/` (recommended for reusability).
2.  **Kernel tuning**: if the service requires kernel parameters or
    sysctl tuning, add them to `modules/tuning/sysctl.nix` rather than
    directly in `configuration.nix`.
3.  **Assertions**: document runtime invariants (e.g., the service must
    reach `active` state) in `docs/ASSERTIONS.md`.

### Adding Home Manager Configuration

1.  **Location**: create a module under `NixOS/modules/home/<category>/`
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
  conflicts[\[1\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix#L7-L40).
- **Boot parameters**: general boot parameters (e.g., `quiet`, `splash`)
  are defined in the boot profile. Hardware‑specific parameters (e.g.,
  `amd_pstate=active`) live in hardware modules such as
  `modules/hardware/amd-gpu.nix`[\[2\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/hardware/amd-gpu.nix#L7-L10).
- **I/O scheduler**: set via `boot.extraModprobeConfig` in
  `sysctl.nix`[\[3\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix#L46-L51).
- **Filesystem maintenance**: `sysctl.nix` defines a one‑shot Btrfs
  optimisation service and periodic maintenance via
  `/etc/btrfs-maintenance.xml`[\[4\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix#L56-L83).

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

  ZRAM            Module          `modules/tuning/zram/`               Memory
                                                                       compression
                                                                       profiles

  Waybar          Service         `modules/home/waybar/`               Status bar with
                                                                       dynamic island

  Noctalia        Service         `modules/home/noctalia/`             Alternative
                                                                       panel (retro
                                                                       style)

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
5.  **Test**: run `nix flake check` and build the system to validate
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

[\[1\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix#L7-L40)
[\[3\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix#L46-L51)
[\[4\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix#L56-L83)
sysctl.nix

<https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix>

[\[2\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/hardware/amd-gpu.nix#L7-L10)
amd-gpu.nix

<https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/hardware/amd-gpu.nix>
