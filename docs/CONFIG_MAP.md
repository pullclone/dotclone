# NyxOS Configuration Map

This document provides a structured map of the NyxOS repository, showing where major files and modules live, the build-time vs runtime boundary, and quick guides for implementation.

## Repository Structure

```
NixOS/
├── configuration.nix               # Main System Policy Orchestrator (Users, Services, Packages)
├── flake.lock
├── flake.nix                       # Flake Entry Point & Module Wiring
├── hardware-configuration.nix      # Generated Hardware Config (Mounts/Filesystems)
├── install.sh                      # Repository-based Installer Script
├── pkgs/                           # Custom Package Derivations
│   ├── latencyflex.nix
│   └── overlay.nix
├── scripts/                        # Maintenance & Test Scripts
│   ├── test-configuration.sh
│   └── test-optimizations.sh
└── modules/                        # Reusable Modules (Domain-Driven)
    ├── boot/                       # Bootloader & Secure Boot Logic
    │   └── boot-profile.nix        # Switchable profile (UKI Baseline vs Lanzaboote)
    ├── core/                       # Installation Facts & Data
    │   └── install-answers.nix     # JSON-like attribute set of install facts (Host, Time, User)
    ├── hardware/                   # Hardware-Specific configurations
    │   └── amd-gpu.nix             # AMD Strix Point kernel params, ROCm, & Graphics
    ├── programs/                   # System-level Program Modules
    │   └── latencyflex-module.nix  # Toggle for the LatencyFleX Vulkan layer
    ├── tuning/                     # Performance & Kernel Tuning
    │   ├── sysctl.nix              # Kernel sysctl, I/O schedulers, Btrfs maintenance
    │   └── zram/                   # ZRAM Profiles
    │       ├── zram-lz4.nix
    │       ├── zram-writeback.nix
    │       ├── zram-zstd-aggressive.nix
    │       └── zram-zstd-balanced.nix
    └── home/                       # Home Manager Configuration
        ├── home-ashy.nix           # HM Entry Point
        ├── apps/                   # User Applications (Brave, Btop, Cava)
        ├── core/                   # Home Options Definition
        ├── niri/                   # Compositor Settings (Niri)
        ├── noctalia/               # Noctalia Panel Config
        ├── shell/                  # Shell Environments (Bash/Fish/Starship)
        ├── terminals/              # Terminal Emulators (Kitty)
        └── waybar/                 # Waybar Panel Config
```

## Build-Time vs Runtime Boundary

### Build-Time Components

- **Flake Definition** (`NixOS/flake.nix`): Defines inputs, outputs, system wiring, and module injection order.
- **Install Facts** (`modules/core/install-answers.nix`): Dynamic facts (Hostname, Timezone, Username, MAC) generated at install time.
- **Domain Modules** (`modules/*`): Specialized logic for Boot, Hardware, and Tuning evaluated at build time.
- **System Policy** (`NixOS/configuration.nix`): High-level policy orchestrator for Services, Users, and Packages.
- **Home Manager Config** (`modules/home/home-ashy.nix`): User environment configuration.

### Runtime Components

- **Services**: Systemd services (SDDM, NetworkManager, Power Profiles) defined in `configuration.nix`.
- **Bootloader**: systemd-boot or Lanzaboote managed by `modules/boot/boot-profile.nix`.
- **Waybar / Noctalia**: Status panels defined in `modules/home/`.
- **Niri**: Wayland compositor.
- **ZRAM**: Memory compression managed by `modules/tuning/zram/`.

## Quick Implementation Guide

### Adding a New Module

1. **Identify Domain**: Determine if it fits in `programs`, `services`, `hardware`, or `tuning`.
2. **Location**: Create in `NixOS/modules/<domain>/`.
3. **Structure**: Follow existing module patterns (`{ config, lib, pkgs, ... }: ...`).
4. **Integration**: Import in `flake.nix` (global) or `configuration.nix` (policy-specific).

### Adding a New Service

1. **Configuration**: Add the service definition to `NixOS/configuration.nix` under the `services = { ... }` block.
2. **Optimization**: If the service requires kernel tuning, add `sysctl` rules to `modules/tuning/sysctl.nix`.
3. **Assertions**: Add runtime checks to `ASSERTIONS.md`.

### Adding Home Manager Configuration

1. **Location**: Create in `NixOS/modules/home/<category>/`.
2. **Structure**: Follow Home Manager module conventions.
3. **Integration**: Import the new file in `modules/home/home-ashy.nix`.
4. **Testing**: Verify with `nixos-rebuild switch` (since HM is integrated into the system flake).

## Kernel Tuning Reference

- **Sysctl Tuning**: Consolidated in `modules/tuning/sysctl.nix`.
  - *Do not* add `boot.kernel.sysctl` to `configuration.nix` to avoid collision errors.
- **Boot Parameters**:
  - General params: `modules/boot/boot-profile.nix`.
  - AMD/Hardware params: `modules/hardware/amd-gpu.nix`.

## Evolving Runtime Component Map

### Current Runtime Components

| Component | Type | Location | Responsibility |
|-----------|------|----------|----------------|
| Bootloader| System | `modules/boot/profile.nix` | Switchable UKI / Secure Boot provider |
| Hardware  | Config | `modules/hardware/amd-gpu.nix` | ROCm, Graphics, Kernel P-States |
| Sysctl    | Config | `modules/tuning/sysctl.nix` | Kernel knobs, I/O scheduling, Btrfs |
| Waybar    | Service| `modules/home/waybar/` | Status bar with dynamic island |
| Niri      | Service| `modules/home/niri/` | Wayland compositor |
| ZRAM      | Module | `modules/tuning/zram/` | Memory compression |
| LatencyFleX| Package| `pkgs/latencyflex.nix` | Vulkan implicit layer for latency reduction |

### Component Relationships

```mermaid
graph TD
    A[Flake Entry] --> B[Boot Profile]
    A --> C[Install Answers]
    A --> D[Hardware & Tuning Modules]
    A --> E[System Policy (Config.nix)]
    A --> F[Home Manager]
    
    C -->|Feeds Facts| E
    D -->|Configures Kernel| E
    
    E --> G[Services]
    E --> H[Packages]
    
    F --> I[Shells]
    F --> J[Desktop (Niri/Waybar/Noctalia)]
    F --> K[Apps]
```

## Change Implementation Flow

1. **Identify Component Domain**: Does this belong in System Policy (`configuration.nix`) or a specialized Domain (`modules/*`)?
2. **Locate Appropriate Directory**: Use this map as a guide.
3. **Follow Existing Patterns**: Match style and structure of similar components.
4. **Update Documentation**: Modify this map if directory structure changes.
5. **Test**: Run `nix flake check` to validate paths and syntax.

## Future Component Planning

- **Container Runtime**: For server profile (likely `modules/virtualization/`).
- **Gaming Layer**: Steam, Wine, etc. (likely `modules/programs/gaming.nix`).
- **Backup System**: Borg or similar (likely `modules/services/backup.nix`).
- **Monitoring**: Prometheus/Grafana stack (currently in `configuration.nix`, candidate for `modules/services/monitoring.nix`).
