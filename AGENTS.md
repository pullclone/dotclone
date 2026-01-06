# NyxOS Agent Guidelines

This document describes the purpose, structure, and operational guidelines for the NyxOS NixOS configuration repository.

## Purpose

NyxOS is a dual-profile NixOS configuration designed for:

- **Desktop Profile**: Full-featured desktop environment with Wayland, gaming support, and productivity tools
- **Server Profile**: Minimal, headless configuration optimized for containerized workloads

## Repository Structure

```
NixOS/
├── modules/              # Reusable NixOS modules
│   ├── home/             # Home Manager configurations
│   ├── waybar/           # Waybar configurations
│   └── ...
├── configuration.nix     # Main system configuration
├── flake.nix             # Flake definition
├── home-ashy.nix         # Home Manager configuration
└── ...
```

## Golden Rules

1. **Deterministic Builds**: All configurations must be reproducible
2. **Module Isolation**: Modules should be self-contained and composable
3. **Documentation First**: Changes must include documentation updates
4. **Test Coverage**: New features require corresponding assertions

## Build Truth

- **Flake-based**: All builds use `nix flake` commands
- **System Target**: Default system is `nyx` (configurable via `SYSTEM` env var)
- **CI Pipeline**: `just ci` runs lint, build, and smoke tests

## Agent Rules

### Change Protocol

1. **Bootstrap**: Run `just bootstrap` to verify tooling
2. **Lint**: Run `just lint` before committing
3. **Build**: Run `just build` to validate changes
4. **Test**: Run `just test` for smoke testing
5. **Document**: Update `docs/CONFIG_MAP.md` and `docs/ASSERTIONS.md`

### Constraints

- **No Impure Builds**: All derivations must be pure
- **No Hardcoded Paths**: Use Nix expressions for paths
- **No Unversioned Dependencies**: All inputs must be pinned

## Testing Expectations

- **Lint Phase**: Shell scripts must pass `shellcheck`
- **Build Phase**: Flake evaluation must succeed
- **Smoke Tests**: Critical binaries must exist in build output
- **Runtime Tests**: System must boot and basic services must start

## Required Output Format

All agent responses must include:

1. **Action Summary**: What was done
2. **Change List**: Files modified/created
3. **Validation**: Test results and build status
4. **Next Steps**: Remaining tasks or follow-up actions

## Agent Special Instructions

See `.agent-instructions.md` for detailed workflow guidance.