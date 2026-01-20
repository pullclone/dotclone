# Security Phases & Rollout Harness

This repository gates security and hardening changes behind a single
authoritative knob so rollouts stay ordered and recoverable.

- **Phase toggle:** `my.security.phase` (0 → observe, 1 → staged, 2 →
  enforced)
- **Break-glass:** `my.security.breakglass.enable` must be true before
  phases >0
- **Assertion guard:** `my.security.assertions.enable` (default true)
  controls whether phase guardrails are enforced

The options live in `modules/security/phase.nix` and are visible via the
usual inspection tools:

```bash
nixos-option --flake .#nyx my.security.phase
nix repl --expr 'builtins.getAttr "my.security" (import ./.).nixosConfigurations.nyx.config'
```

## Phase meanings

- **0 — Observe / harness only**
  - Keep security options in a no-op state and verify merge results.
  - Safe commands: `just sec-preview <target>` to build + dry-activate,
    `nixos-option` to inspect merged values.
- **1 — Staged apply**
  - Use for PAM/U2F or locker changes that should survive a reboot but
    are easy to roll back.
  - Requires `my.security.breakglass.enable = true`.
  - Run `just sec-preview <target>` then `just sec-test <target>`
    (`nixos-rebuild test`) before any switch/boot.
- **2 — Enforced**
  - Boot- or auth-critical changes (e.g., Secure Boot signing, PAM hard
    gating) belong here.
  - Always verify with phase 1 first; only switch once dry-activation
    and test rebuilds are clean.

## Rollout harness (doas-first)

The Justfile provides pinned entry points that match the NixOS manual
guidance for safe rollouts:

- `just sec-preview <target>` — build
  `.#nixosConfigurations.<target>.config.system.build.toplevel` and run
  `switch-to-configuration dry-activate` via `doas`.
- `just sec-test <target>` — `doas nixos-rebuild test --flake .#<target>`
  to stage the build without setting it as default.
- `just sec-switch <target>` — `doas nixos-rebuild switch --flake .#<target>`
  (use after preview + test).

## Guardrails and assumptions

- `sudo` stays disabled; `doas` is the elevation path for rebuilds and
  dry-activation.
- SSH root login remains off; keep at least one strong-password admin
  user plus a documented break-glass path before raising the phase.
- Noctalia is treated as the primary locker surface; avoid enabling
  competing lock handlers without a phase-1 preview.
- Trezor One support is scoped to userland identity (U2F, SSH agent).
  Initrd/LUKS unlock remains a paper design until a minimal, tested
  path exists.
