# NyxOS Configuration Map

This document maps where core files live, how profiles compose, and how to
safely locate and edit features. Detailed reference material is in the
appendices.

## Quick map (main)

- Entry points: `configuration.nix`, `flake.nix`, `install-nyxos.sh`.
- Facts vs policy: install answers live in `modules/core/install-answers.nix`
  and are exported as `config.my.install` for policy modules to consume.
- Domain modules: `modules/{boot,core,hardware,networking,programs,tuning,security,ssh,home}`.
- Profiles: `profiles/` define system and ZRAM tuning (flake arg driven).
- Scripts: `scripts/` contains audits and runtime checks used by `just`.

## Profiles and composition

- Official profiles: `latency`, `balanced`, `throughput`, `battery`,
  `memory-saver`.
- Realized outputs: `nyx-<profile>-lfx-<on|off>` (10 total) plus alias
  `nyx -> nyx-balanced-lfx-on`.
- Build/switch examples:
  - `just build` / `just switch` (env overrides: `SYSTEM_PROFILE`,
    `LATENCYFLEX_ENABLE`)
  - `nix build .#nixosConfigurations.nyx-<profile>-lfx-<on|off>.config.system.build.toplevel`
  - `sudo nixos-rebuild switch --flake .#nyx-<profile>-lfx-<on|off>`

## Safe editing guide

1. Identify the domain: `boot`, `hardware`, `tuning`, `programs`,
   `security`, or `home`.
2. Locate existing patterns in `modules/` and follow their structure.
3. Keep sysctl in `modules/tuning/sysctl.nix`; boot params in boot or
   hardware modules.
4. Update docs and assertions for non-trivial changes.
5. Validate with `just audit`, then build and test.

## Build and lint workflow

- `nix develop .#agent`: enter the pinned toolchain.
- `just audit`: formatting gate, flake check/build, contract checks,
  shellcheck strict/advisory.
- `just build` / `just test`: build and smoke tests.
- See `docs/PREFLIGHT.md` and `docs/LINT_POLICY.md` for details.

## Appendices

### Appendix A: Repository structure

    ├── configuration.nix               # Main system policy orchestrator (services, users, packages)
    ├── flake.lock
    ├── flake.nix                       # Flake entry point and module wiring (rooted here; no ./NixOS)
    ├── hardware-configuration.nix      # Generated hardware config (mounts/filesystems)
    ├── install-nyxos.sh                # Installer (LUKS2 root + optional persist, dry-run build mode)
    ├── overlays/                       # Override/extend packages for system and Home Manager
    │   └── latencyflex.nix             # Exposes LatencyFleX as pkgs.latencyflex
    ├── pkgs/                           # Custom package derivations
    ├── profiles/                       # Flake-native system + ZRAM profile set
    ├── templates/
    │   ├── research/                   # Opt-in, standalone research flake
    │   └── ssh/                        # Declarative SSH client/server templates
    ├── scripts/                        # Maintenance and test scripts
    │   ├── audit-repo.sh               # Contract + flake/build audit
    │   ├── test-configuration.sh       # Static sanity checks against configuration files
    │   └── test-optimizations.sh       # Runtime optimization checks (optional)
    └── modules/                        # Reusable modules (domain-driven)
        ├── boot/                       # Bootloader and Secure Boot logic
        │   └── boot-profile.nix        # Switchable profile (UKI vs Lanzaboote/Secure Boot)
        ├── core/                       # Installation facts and data
        │   ├── install-answers.nix     # Hostname, timezone, user, MAC answers
        │   ├── keyboard-preset.nix     # Console + XKB keyboard preset wiring
        │   └── xkb/                    # Custom XKB symbols for nonstandard layouts
        ├── hardware/                   # Hardware-specific configurations
        │   ├── amd-gpu.nix             # AMD kernel params and ROCm stack
        │   └── nvidia-gpu.nix          # Install-driven NVIDIA/PRIME wiring
        ├── networking/                 # Network policy modules
        │   ├── ipv6.nix                # IPv6 enablement + temp addresses
        │   └── tcp.nix                 # TCP congestion control kernel module
        ├── programs/                   # System-level program modules
        │   └── latencyflex-module.nix  # Toggle for the LatencyFleX Vulkan layer
        ├── tuning/                     # Performance and kernel tuning
        │   └── sysctl.nix              # Kernel sysctl, IO schedulers, Btrfs maintenance
        ├── security/                   # Hardening modules
        ├── ssh/                        # Declarative SSH client/server profiles
        └── home/                       # Home Manager configuration
            ├── home-ashy.nix           # HM entry point
            ├── apps/                   # User applications (Brave, Btop, Cava)
            ├── core/                   # Home options definition
            ├── niri/                   # Compositor settings (Niri)
            ├── noctalia/               # Noctalia panel config
            ├── shell/                  # Shell environments (Bash/Fish/Starship)
            ├── terminals/              # Terminal emulators (Kitty)
            └── waybar/                 # Waybar panel config

### Appendix B: Noteworthy files

- `modules/core/install-answers.nix`: reads `/etc/nixos/nyxos-install.nix` and
  exports `config.my.install` facts.
- `install-nyxos.sh`: installer with LUKS2 root, optional persist partition,
  and dry-run build validation.
- `modules/core/keyboard-preset.nix`: single keyboard preset across initrd/TTY
  and XKB sessions.
- `modules/boot/boot-profile.nix`: mutually exclusive boot profiles (UKI vs
  Secure Boot) with assertions.
- `modules/networking/ipv6.nix`: install-driven IPv6 enablement and temp-address defaults.
- `modules/networking/tcp.nix`: install-driven TCP congestion control kernel module.
- `modules/tuning/sysctl.nix`: the sole source for `boot.kernel.sysctl`.
- `modules/security/phase.nix`: `my.security.phase`, `my.security.breakglass`,
  and assertions gating.
- `modules/security/access.nix`: least-privilege doas rules and break-glass
  gating.
- `modules/security/locker-pam.nix`: locker selection assertions and auditing.
- `modules/security/time-sync.nix`: Chrony with NTS defaults.
- `modules/security/systemd-hardening.nix`: global NoNewPrivileges defaults.
- `modules/security/usbguard.nix`: USBGuard gating by security phase.
- `modules/security/u2f.nix`: phased pam_u2f wiring.
- `modules/security/fingerprint.nix`: optional pam_fprintd wiring.
- `modules/security/aide.nix`: optional AIDE service/timer.
- `modules/security/lynis.nix`: optional Lynis audit service/timer.
- `modules/security/luks-gpg.nix`: initrd GPG decrypt flow for LUKS keyfiles.
- `modules/ssh/default.nix`: declarative SSH client/server profile wiring.
- `modules/programs/gaming.nix`: optional gaming stack based on install facts.
- `modules/home/apps/ssh-identity.nix`: SSH identity wiring from install facts.
- `modules/home/apps/trezor-agent.nix`: optional trezor-agent service.
- `modules/home/apps/protonvpn.nix`: optional ProtonVPN GUI.
- `modules/boot/uki.nix`: Bootspec with NyxOS UKI extension.
- `profiles/`: system + ZRAM profiles (finite outputs).
- `pkgs/latencyflex.nix`: LatencyFleX derivation and manifest.
- `templates/ssh/`: SSH client/server templates (profiles + features).
- `templates/ssh/known-hosts/host-ca-skeleton.nix`: CA bundle scaffolding (off by default).
- `docs/OPERATIONS.md`: daily-use cheat sheet.
- `docs/SSH_CA_WORKFLOW.md`: host CA scaffolding and guardrails.
- `docs/SECURITY_AND_RECOVERY.md`: security phases and recovery guidance.
- `docs/REPRODUCIBILITY.md`: release provenance snippet.
- `scripts/audit-locker.sh`: locker/PAM audit helper.
- `scripts/usbguard-generate-policy.sh`: USBGuard allowlist generator.
- `scripts/rsi-launcher.sh`: helper wrapper for RSI launcher or Lutris setup.
- `templates/research/`: opt-in research flake with pinned devShell.

### Appendix C: Build-time vs runtime boundary

#### Build-time components

- Flake definition (`flake.nix`): pins inputs and wires modules.
- Install facts (`modules/core/install-answers.nix`): dynamic facts collected
  at install time.
- Domain modules (`modules/*`): boot, hardware, tuning, home.
- System policy (`configuration.nix`): services, users, packages, imports.
- Home Manager config (`modules/home/home-ashy.nix`): user environment.
- Custom packages (`pkgs/`): local overrides and derivations.

#### Install facts contract

Install-time facts are collected once by `install-nyxos.sh` and written to:

- `/etc/nixos/nyxos-install.nix`

These facts are loaded exactly once by:

- `modules/core/install-answers.nix`

and re-exported as `config.my.install`.

Rules:

- No other module may import `nyxos-install.nix` directly.
- All system, boot, tuning, snapshot, and trust logic must consume install
  decisions via `config.my.install`.
- This file represents facts, not policy.
- LUKS GPG unlock must reference encrypted key material from a persistent mount.
- Gaming selections map to `modules/programs/gaming.nix` policy.

#### Runtime components

- Bootloader: systemd-boot or Lanzaboote (via `boot-profile.nix`).
- Services: systemd services declared in `configuration.nix` and modules.
- Wayland compositor: Niri (`modules/home/niri/`).
- Panels: Waybar and/or Noctalia (`modules/home/waybar`, `modules/home/noctalia`).
- System/ZRAM profile: flake-selected profiles under `profiles/`.
- Filesystem maintenance: periodic defrag/balance/scrub/trim in `sysctl.nix`.

### Appendix D: Kernel tuning reference

- Sysctl tuning: `modules/tuning/sysctl.nix` (only location for
  `boot.kernel.sysctl`).
- Boot parameters: boot profile or hardware modules.
- IO scheduler: set via `boot.extraModprobeConfig` in `sysctl.nix`.
- Filesystem maintenance: `sysctl.nix` defines Btrfs maintenance services.

### Appendix E: Runtime component map

  -----------------------------------------------------------------------------
  Component       Type            Location                             Purpose
  --------------- --------------- ------------------------------------ ----------------
  Bootloader      System          `modules/boot/boot-profile.nix`      UKI or Secure Boot
  Install Facts   Config          `modules/core/install-answers.nix`   Hostname/timezone/user facts
  Hardware        Config          `modules/hardware/amd-gpu.nix`       ROCm packages, kernel params
  Sysctl          Config          `modules/tuning/sysctl.nix`          Kernel sysctl, IO scheduler
  Snapshots       Service         `modules/tuning/btrfs-snapshots.nix` Btrfs snapshot policy
  System Profile  Module          `profiles/system/`                   System + ZRAM tuning
  Waybar          Service         `modules/home/waybar/`               Status bar
  Noctalia        Service         `modules/home/noctalia/`             Alternative panel
  Niri            Service         `modules/home/niri/`                 Wayland compositor
  LatencyFleX     Package         `pkgs/latencyflex.nix`               Vulkan implicit layer
  Btrfs Maint.    Service         `modules/tuning/sysctl.nix`          Defrag, balance, scrub, trim
  -----------------------------------------------------------------------------

#### Component relationships

    graph TD
        A[Flake Entry] --> B[Boot Profile]
        A --> C[Install Answers]
        A --> D[Hardware and Tuning Modules]
        A --> E[System Policy (configuration.nix)]
        A --> F[Home Manager]

        C -->|Feeds Facts| E
        D -->|Configures Kernel| E

        E --> G[Services]
        E --> H[System Packages]

        F --> I[Shells]
        F --> J[Desktop (Niri/Waybar/Noctalia)]
        F --> K[Apps]

### Appendix F: Planned updates and installer map

Planned updates (install/trust/snapshot wiring):

- Align boot profile selection with install answers (`boot.mode`).
- Derive snapshot services/retention from `my.install.snapshots.*`.
- Normalize storage trim and encryption intent from install schema.

Installer -> answers -> consumer map:

| Installer prompt                        | Answers file field                        | Consumed by                               |
| --------------------------------------- | ----------------------------------------- | ----------------------------------------- |
| Username                                | `userName`                                | `modules/core/install-answers.nix` -> `config.my.install.userName` (users) |
| Hostname                                | `hostName`                                | `modules/core/install-answers.nix` -> `networking.hostName`                |
| Timezone                                | `timeZone`                                | `modules/core/install-answers.nix` -> `time.timeZone`                     |
| MAC mode/interface/address              | `mac.mode/interface/address`              | `modules/core/install-answers.nix` -> NetworkManager policy                |
| Boot mode                               | `boot.mode`                               | `modules/boot/boot-profile.nix` (selects UKI vs Secure Boot)              |
| Trust phase                             | `trust.phase`                             | Boot/Secure Boot gating                                                     |
| Desktop panel                           | `desktop.panel`                           | Home Manager panel selection (planned)                                      |
| Snapshot policy                         | `snapshots.*`                             | Snapshot services (planned)                                                 |
| Trim policy                             | `storage.trim.*`                          | Storage maintenance (planned)                                               |
| Encryption intent                       | `encryption.mode`                         | Future LUKS wiring                                                          |
| Swap mode/size                          | `swap.mode/sizeGiB`                       | Swap provisioning                                                           |
| IPv6 policy                             | `networking.ipv6.enable/tempAddresses`    | Network stack policy (planned)                                              |
| TCP congestion control                  | `networking.tcp.congestionControl`        | Kernel tuning (planned)                                                     |
| System profile                          | `profile.system`                          | Flake arg -> system profile selection                                       |
| Auto-upgrade                            | `autoUpgrade.*`                           | Systemd auto-upgrade timer (planned)                                        |
| Container stack                         | `my.programs.containers.enable`           | `modules/programs/containers.nix`                                           |

### Appendix G: Future component planning

- Container runtime: `modules/virtualization/` (LXC/Incus or Podman).
- Gaming layer: `modules/programs/gaming.nix`.
- Backup system: `modules/services/backup.nix`.
- Monitoring: split Prometheus/Grafana under `modules/services/monitoring.nix`.
- Server profile: separate NixOS configuration for server use.
