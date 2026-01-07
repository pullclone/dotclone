# NyxOS Runtime Assertions and Build Contracts

This document defines the runtime invariants, machine-checkable assertions, and build contracts for the NyxOS NixOS configuration.

## Core Build Contract

### Flake Evaluation

- **Deterministic**: `nix flake check` must pass without warnings
- **Input Purity**: All flake inputs must be pinned and reproducible
- **Output Completeness**: All declared outputs must be buildable

### System Configuration

- **Module Validity**: All NixOS modules must evaluate without errors
- **Option Types**: All module options must have explicit types
- **No Warnings**: `nix-build` must complete without warnings
- **Sysctl Coherence**: Kernel sysctl values live in one consolidated block and must not be defined with conflicting values elsewhere

### Home Manager

- **Config Validity**: Home Manager configuration must evaluate cleanly
- **No Conflicts**: No overlapping or conflicting home configurations
- **User Isolation**: Home configurations must not affect system services

## Module Model Assertions

### Module Structure

- **Self-Contained**: Each module must declare its own options
- **No Circular Dependencies**: Module imports must form a DAG
- **Explicit Imports**: All module dependencies must be explicitly imported

### Module Behavior

- **Idempotent**: Multiple imports of same module must have same effect
- **Isolated**: Modules must not modify global state unexpectedly
- **Documented**: All module options must have descriptions

## User/Desktop Invariants

### Desktop Environment

- **Wayland Session**: Default session must be Wayland-based
- **Compositor**: Niri must be available and configurable
- **Status Bar**: Waybar must start automatically and show dynamic island

### User Applications

- **Terminal Availability**: Configured terminals must be installable
- **Application Configs**: All app configurations must be valid for their targets
- **No Broken Symlinks**: Home Manager must not create broken symlinks

## Hardware Expectations

### Minimum Requirements

- **Memory**: System must boot and run with 4GB RAM
- **Storage**: Configuration must fit within 20GB disk space
- **CPU**: Must support basic x86_64 instruction set

### Optional Hardware Support

- **ZRAM**: If enabled, must compress memory effectively
- **GPU Acceleration**: Wayland must utilize available GPU
- **Input Devices**: Must handle keyboard, mouse, and touchpad

## Service Requirements

### Critical Services

- **Systemd**: Must start all enabled services successfully
- **Networking**: Must provide functional network stack
- **Logging**: Must capture and persist system logs

### Desktop Services

- **Waybar**: Must start and display system information
- **Niri**: Must manage Wayland sessions
- **Home Manager**: Must apply user configurations

## Package Requirements

### Core Packages

- **Nix**: Must be available for package management
- **System Packages**: All declared system packages must be installable
- **Home Packages**: All home packages must be available to user

### Quality Gates

- **No Broken Packages**: All packages must resolve successfully
- **Version Pinning**: Critical packages must have pinned versions
- **No Conflicts**: Package set must be conflict-free

## CI Policy

### Build Pipeline

- **Lint Phase**: Must pass all linting checks
- **Build Phase**: Must complete successfully
- **Test Phase**: Must pass all smoke tests
- **Documentation**: Must be up-to-date with code

### Test Coverage

- **Smoke Tests**: Critical binaries must exist in build output
- **LatencyFleX Layer**: `latencyflex.json` must exist in build output
- **Integration Tests**: Services must start in test environment
- **Regression Tests**: Changes must not break existing functionality

### Quality Gates

- **No Warnings**: Build must complete without warnings
- **Deterministic**: Identical inputs must produce identical outputs
- **Reproducible**: Builds must be reproducible across environments

## Runtime Assertions

### Boot Process

- **Systemd**: Must reach multi-user.target successfully
- **Critical Services**: Must be active after boot
- **Filesystem**: Must be mounted correctly

### User Session

- **Login**: Must be possible via configured methods
- **Shell**: Must start with correct environment
- **Applications**: Must launch successfully

### System Health

- **Memory**: Must not leak memory over time
- **CPU**: Must not have runaway processes
- **Disk**: Must not fill up unexpectedly

## Verification Commands

### Build Verification

```bash
# Check flake evaluation
nix flake check

# Build system configuration
nix build ".#nixosConfigurations.nyx.config.system.build.toplevel"

# Verify critical binary exists
[ -x "./result/sw/bin/g502-manager" ]

# Verify LatencyFleX layer manifest exists
[ -f "./result/sw/share/vulkan/implicit_layer.d/latencyflex.json" ]
```

### Runtime Verification

```bash
# Check systemd services
systemctl status

# Verify Wayland session
loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type

# Check Waybar status
systemctl --user status waybar
```

### Continuous Verification

- **CI Pipeline**: `just ci` must pass on all commits
- **Pre-commit Hooks**: Must run lint and basic checks
- **Post-deploy Checks**: Must verify critical services

## Assertion Maintenance

### Adding New Assertions

1. **Identify Invariant**: Determine what needs to be guaranteed
2. **Define Check**: Create machine-verifiable assertion
3. **Add to CI**: Integrate into test pipeline
4. **Document**: Update this file with new assertion

### Assertion Lifecycle

- **Proposal**: New assertions proposed in PRs
- **Review**: Assertions reviewed for completeness
- **Implementation**: Assertions added to test suite
- **Maintenance**: Assertions updated as system evolves
