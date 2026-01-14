# NyxOS Runtime Assertions and Build Contracts

This document defines the **runtime invariants**, **machine‑checkable
assertions**, and **build contracts** for the NyxOS configuration.
Assertions are treated as **contracts**: they are scoped (either
build‑time or runtime), verifiable, and owned by a specific domain. They
are **not** aspirational goals or loose health checks. If an assertion
cannot be expressed in deterministic, machine‑checkable terms, it does
not belong here.

## Build‑Time Contracts

These assertions apply when evaluating the flake and building the
system. They must hold before any runtime logic executes.

### 1. Flake & Build Graph

- **Determinism** -- `nix flake check` must complete without warnings.
  All inputs are pinned and reproducible, and all declared outputs are
  buildable.
- **Complete Outputs** -- The flake must expose all system variants
  (e.g., `nyx`) and user environments defined in the repository. Any
  referenced module must be imported in the flake to avoid "missing
  output" errors.

### 2. Boot & Trust Chain

NyxOS supports two mutually exclusive boot flows defined in
`modules/boot/boot-profile.nix`: a **UKI baseline** using systemd‑boot
and a **Secure Boot** profile using Lanzaboote and `sbctl`. The module
itself enforces this exclusivity with a Nix
assertion[\[1\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/boot/boot-profile.nix#L16-L21).
<!-- TODO(batch1): Expand with trust.phase-driven enforcement once install facts are hooked in. -->

- **Exclusive Selection** -- Exactly one of `my.boot.uki.enable` or
  `my.boot.secureBoot.enable` must be set. Builds must fail if both or
  neither are enabled.
  When `my.install.boot.mode` is provided, it must map to exactly one
  of these flags.
- **Trust Phase Awareness** -- Assertions related to Secure Boot
  enforcement and TPM state must respect `my.trust.phase`. When
  `my.trust.phase = "dev"`, firmware enforcement and TPM sealing
  assertions must not be required.
- **Secure Boot Readiness (Dev)** -- When Secure Boot is selected and
  `my.trust.phase = "dev"`, NyxOS must be capable of producing signed
  boot artifacts (Lanzaboote + sbctl) or a UKI (systemd‑boot path), but
  must not assert firmware Secure Boot enforcement or TPM PCR state.
- **Secure Boot Enforcement (Prod)** -- When `my.trust.phase = "enforced"`
  and Secure Boot is selected, the build may require firmware Secure
  Boot to be enabled and the signing path to be present; TPM checks are
  deferred until this phase.
- **TPM Unlock (Enforced, Manual Enrollment)** -- In enforced trust
  phase, TPM+PIN unlock is expected to be available for encrypted
  installs, but enrollment is manual. The passphrase must remain as a
  fallback. Manual command (adjust UUID):  
  `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7+14 --tpm2-with-pin=yes /dev/disk/by-uuid/XXXX`
- **UKI Profile** -- When `my.boot.uki.enable = true`, the following
  must hold:
- `boot.loader.systemd-boot.enable = true` with `editor = false` and a
  finite
  `configurationLimit`[\[2\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/boot/boot-profile.nix#L52-L59).
- `boot.initrd.systemd.enable = true` and
  `boot.loader.efi.canTouchEfiVariables = true`[\[3\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/boot/boot-profile.nix#L29-L35).
- **Secure Boot Profile** -- When `my.boot.secureBoot.enable = true`,
  the Lanzaboote module must be imported and the package `sbctl`
  available[\[4\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/boot/boot-profile.nix#L64-L70).
  Systemd‑boot must be disabled
  (`lib.mkForce false`)[\[5\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/boot/boot-profile.nix#L70-L72)
  and the `lanzaboote` options configured.

### 3. Install Facts

NyxOS separates **facts** (collected at install time) from **policy**.
The module `modules/core/install-answers.nix` reads an
`/etc/nixos/nyxos-install.nix` file containing attributes such as
`hostName`, `timeZone`, `userName`, and
`mac`[\[6\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/core/install-answers.nix#L4-L11).
The answers file may also include additional install-time facts (e.g.,
snapshot policy, storage preferences, encryption intent). These are
normalized by `modules/core/install-answers.nix` and re-exported via
`config.my.install`.
<!-- TODO(batch1): Document expanded schema defaults/validation once wired into modules. -->

- **Required Fact** -- `my.install.userName` must be a non‑empty
  string[\[7\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/core/install-answers.nix#L14-L18).
  The build must fail if it is empty or missing.
- **Hostname & Timezone** -- `networking.hostName` and `time.timeZone`
  must be set via install
  facts[\[8\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/core/install-answers.nix#L22-L24).
  Defaults (`nyx`, `UTC`) are allowed only when the corresponding field
  is not provided.
- **MAC Address Mode** -- The `mac.mode` attribute must be one of
  `default`, `random`, `stable`, or `fixed` and drive the NetworkManager
  configuration[\[9\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/core/install-answers.nix#L25-L32).
  If `mac.mode = "fixed"`, `mac.address` and `mac.interface` must be
  provided.

### 4. Kernel & Tuning

All kernel tuning lives in `modules/tuning/sysctl.nix`, which defines
`boot.kernel.sysctl` for memory management, security, and
networking[\[10\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix#L7-L40).
Modules such as ZRAM may override specific keys via `mkDefault` or
`mkOverride`, but no other files may introduce new sysctl keys.

- **Centralization** -- There must be exactly one source of
  `boot.kernel.sysctl` definitions. If any module outside
  `modules/tuning` defines `boot.kernel.sysctl`, the build should fail.
- **System/ZRAM Profiles** -- Exactly one system profile is selected via
  the flake argument `systemProfile`, sourced from `profiles/`. Each
  system profile imports a ZRAM profile and sets `zramSwap.enable = true`
  plus defaults for `memoryPercent`, `priority`, `vm.swappiness`,
  `vm.watermark_scale_factor`, `vm.page-cluster`, and writeback knobs
  when applicable. Using the writeback profile still requires setting a
  backing device when `my.swap.writeback.enable = true`[\[11\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/profiles/zram/writeback.nix#L6-L46).
- **I/O Schedulers & Btrfs Maintenance** -- The `sysctl` module defines
  the I/O scheduler and a one‑shot `btrfs-optimize` service plus
  periodic maintenance via
  `btrfs-maintenance.xml`[\[12\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix#L56-L83).
  These files must exist in the generated system and be enabled.

### 5. Hardware Profiles

Hardware‑specific modules encapsulate kernel parameters and packages.
For example, `modules/hardware/amd-gpu.nix` sets AMD P‑state and GPU
feature
masks[\[13\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/hardware/amd-gpu.nix#L7-L10)
and enables ROCm
packages[\[14\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/hardware/amd-gpu.nix#L15-L21).

- **Kernel Parameters Owned by Hardware Modules** -- Only hardware
  modules may set `boot.kernelParams` for hardware features.
  `configuration.nix` must not override these values.
- **Package Requirements** -- When a hardware module is imported, all
  its declared packages must be included in
  `environment.systemPackages`. For AMD, this includes `rocm-smi`,
  `rocminfo` and
  `nvtop`[\[15\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/hardware/amd-gpu.nix#L30-L36).
- **No Cross‑Domain Leakage** -- Hardware modules must not define sysctl
  keys, bootloader settings, or service units. They may only configure
  hardware and install packages.

### 6. Service Definitions

  System services are declared in `configuration.nix` and modules under
`modules/`. The build contract asserts:

- **Critical Services Active** -- Systemd must start all enabled
  services (SDDM, NetworkManager, Btrfs maintenance, etc.). Services
  defined but not enabled must not linger in a partially configured
  state.
- **Filesystems & Snapshots** -- All filesystems declared in
  `hardware-configuration.nix` must mount successfully. If snapshots via
  Btrfs are enabled, the snapshot services must be present. When
  `my.install.snapshots.retention = -1`, snapshot tooling remains
  disabled. When `retention = 0`, btrbk must be explicitly disabled.
  When `retention > 0`, btrbk services and timers must be enabled and
  exclude `/nix` from targets.
- **Remote Snapshot Guardrails** -- If `my.install.snapshots.remote.enable = true`,
  `my.install.snapshots.remote.target` must be non-empty. Remote targets
  should be restricted (SSH key limited to `btrfs receive`, no agent
  forwarding).
- **Snapshot Semantics** -- Snapshot behavior must be derived from
  `my.install.snapshots.retention`:
  - `-1` means snapshots are not configured and no snapshot
    tooling/services are enabled.
  - `0` means snapshots are explicitly disabled.
  - `>0` means snapshot tooling/services must be enabled and retention
    enforced.

### 7. User Environment & Home Manager

Home Manager configuration lives under `modules/home/`. The build
asserts:

- **Evaluation** -- The Home Manager configuration must evaluate without
  errors and must not modify global system state. Modules should expose
  options and import dependencies explicitly.
- **Exclusivity** -- Only one compositor (e.g., Niri) and one panel
  (Waybar or Noctalia) may be enabled. Only one terminal module should
  be selected as the default.
- **Isolation** -- Home modules must not declare systemd services or
  system packages. They operate on the user's home environment only.
- **No Broken Symlinks** -- Home Manager must not produce dead symlinks
  in the user's home.

### 8. Package Requirements

NyxOS distinguishes system packages (declared in `configuration.nix`)
from user packages (via Home Manager) and custom packages (under
`pkgs/`).

- **Nix Availability** -- The `nix` package must be present to allow
  installation of additional software.
- **Custom Packages** -- Packages such as the LatencyFleX Vulkan layer
  must install both the shared library and its manifest
  file[\[16\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/pkgs/latencyflex.nix#L29-L49).
  When a hardware profile is enabled, its dependent packages (e.g.,
  ROCm) must be installable.
- **Quality Gates** -- All packages must build successfully with pinned
  versions. No package set (system or user) may produce conflicts or
  unresolved dependencies.

### 9. CI & Verification

The repository's Justfile defines a CI pipeline. Assertions link to
these steps:

- **Lint Phase** -- Code must pass formatting and linting as defined by
  the Justfile.
- **Build Phase** --
  `nix build .#nixosConfigurations.<variant>.config.system.build.toplevel`
  must complete successfully for each system variant. The variant name
  is derived from the install facts (`hostName`), defaulting to `nyx`.
- **Test Phase** -- Custom scripts (`scripts/test-configuration.sh`,
  `scripts/test-optimizations.sh`) must pass. Smoke tests must verify
  the presence of critical binaries such as `rocminfo` (when AMD profile
  is active) and `latencyflex.json`.
- **Determinism** -- The build must be reproducible across environments:
  identical inputs produce identical outputs.

## Runtime Contracts

These assertions must hold on a running system after activation.

### 1. Boot Process

- **Reach Multi‑User Target** -- Systemd must reach `multi-user.target`
  without failed units.
- **Bootloader Integrity** -- The selected bootloader (systemd‑boot or
  Lanzaboote) must be active and correspond to the chosen profile.
- **Filesystem Health** -- All filesystems must mount without errors;
  Btrfs maintenance services should create logs but not fail. If an
  encrypted LUKS volume is used, it must unlock via the configured
  mechanism (passphrase or TPM+PIN).

### 2. User Session

- **Login Success** -- Users must be able to log in via the configured
  display manager (SDDM) and start a Wayland session.
- **Shell Environment** -- The user's default shell (e.g., Bash or Fish)
  should start with the expected environment variables.
- **Application Launch** -- Configured applications (browser, terminal
  emulator, panel, etc.) must launch without errors.

### 3. System Health

- **Memory & Swap** -- If ZRAM is enabled, the `zram0` device must be
  present and sized according to the selected profile. The system must
  not leak memory excessively; swap usage should remain within expected
  bounds.
- **CPU & Processes** -- There must be no runaway processes consuming
  100% CPU for extended periods under idle conditions.
- **Disk Utilization** -- Disk usage must not grow unexpectedly beyond
  the retention policy for snapshots and caches. Btrfs subvolumes and
  maintenance tasks should keep usage under control.

## Verification Commands

The following commands can be used to verify the assertions manually or
from CI scripts. Adjust variant names as needed.

    # Flake evaluation
    nix flake check

    # Build system configuration for host 'nyx' (replace with your hostname)
    nix build .#nixosConfigurations.nyx.config.system.build.toplevel

    # Ensure only one boot profile is enabled
    nixos-option my.boot.uki.enable && nixos-option my.boot.secureBoot.enable && echo "Error: both UKI and secureBoot profiles are enabled"

    # Verify critical binaries (examples)
    [ -x ./result/sw/bin/rocminfo ]      # AMD profile
    [ -f ./result/sw/share/vulkan/implicit_layer.d/latencyflex.json ]

    # Check that ZRAM exists and is sized correctly (optional)
    lsblk -o NAME,TYPE,SIZE | grep zram0

    # Verify Btrfs maintenance config
    [ -f /etc/btrfs-maintenance.xml ]

    # Check Wayland session type
    loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type

    # Check user panels
    systemctl --user status waybar || systemctl --user status noctalia

    # Noctalia service ownership (HM module only; avoid NixOS service duplication)
    systemctl --user show -p FragmentPath noctalia-shell.service

## Assertion Maintenance

### Adding New Assertions

1.  **Identify the invariant** -- Determine what behaviour must be
    guaranteed and decide whether it is build‑time or runtime.
2.  **Define the check** -- Express the invariant in deterministic,
    machine‑verifiable terms. Avoid ambiguous wording.
3.  **Integrate with CI** -- Add tests or verifications to the
    appropriate phase (lint, build, test) in the Justfile or scripts.
4.  **Document** -- Update this file, specifying the domain that owns
    the assertion.

### Assertion Lifecycle

- **Proposal** -- New assertions are proposed in pull requests and
  discuss how they align with the domains defined above.
- **Review** -- Assertions are reviewed for completeness, determinism,
  and minimal false positives.
- **Implementation** -- Approved assertions are added to code (via Nix
  assertions or CI tests) and documented here.
- **Maintenance** -- As the system evolves, existing assertions may need
  to be updated or removed. Always update this document when the source
  of truth changes.

------------------------------------------------------------------------

[\[1\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/boot/boot-profile.nix#L16-L21)
[\[2\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/boot/boot-profile.nix#L52-L59)
[\[3\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/boot/boot-profile.nix#L29-L35)
[\[4\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/boot/boot-profile.nix#L64-L70)
[\[5\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/boot/boot-profile.nix#L70-L72)
boot-profile.nix

<https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/boot/boot-profile.nix>

[\[6\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/core/install-answers.nix#L4-L11)
[\[7\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/core/install-answers.nix#L14-L18)
[\[8\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/core/install-answers.nix#L22-L24)
[\[9\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/core/install-answers.nix#L25-L32)
install-answers.nix

<https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/core/install-answers.nix>

[\[10\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix#L7-L40)
[\[12\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix#L56-L83)
sysctl.nix

<https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/tuning/sysctl.nix>

[\[11\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/profiles/zram/writeback.nix#L6-L46)
profiles/zram/writeback.nix

<https://github.com/pullclone/dotclone/blob/HEAD/NixOS/profiles/zram/writeback.nix>

[\[13\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/hardware/amd-gpu.nix#L7-L10)
[\[14\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/hardware/amd-gpu.nix#L15-L21)
[\[15\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/hardware/amd-gpu.nix#L30-L36)
amd-gpu.nix

<https://github.com/pullclone/dotclone/blob/HEAD/NixOS/modules/hardware/amd-gpu.nix>

[\[16\]](https://github.com/pullclone/dotclone/blob/HEAD/NixOS/pkgs/latencyflex.nix#L29-L49)
latencyflex.nix

<https://github.com/pullclone/dotclone/blob/HEAD/NixOS/pkgs/latencyflex.nix>
