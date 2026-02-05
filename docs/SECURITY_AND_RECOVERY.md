# Security and Recovery

This document consolidates security phases, security assertions, and
break-glass recovery guidance. It replaces `SECURITY_PHASES.md` and
`RECOVERY.md`.

## Security phase controls

NyxOS gates hardening behind a single knob so rollouts stay ordered and
recoverable.

- Phase toggle: `my.security.phase` (0 -> observe, 1 -> staged, 2 -> enforced)
- Break-glass: `my.security.breakglass.enable` must be true before phases > 0
- Assertion guard: `my.security.assertions.enable` (default true)

The options live in `modules/security/phase.nix`.

## Phase meanings

- Phase 0 (observe): no-op hardening; verify merge results and options.
- Phase 1 (staged): PAM/U2F/locker changes that should survive reboot and are
  easy to roll back. Requires break-glass.
- Phase 2 (enforced): boot- or auth-critical changes (Secure Boot signing,
  hard PAM gating). Always validate with phase 1 first.

## Boot and trust chain assertions (summary)

- Exactly one boot profile is enabled: `my.boot.uki.enable` or
  `my.boot.secureBoot.enable`.
- Trust phase (`my.trust.phase`) gates Secure Boot/TPM enforcement.
- Secure Boot readiness is required in dev; enforcement is required in
  enforced phase.
- TPM+PIN unlock is expected in enforced phase; installer can enroll when
  `encryption.tpm2.enable = true`, otherwise use manual enrollment.
- UKI and Secure Boot profiles must set the expected bootloader options.
- Bootspec extension namespace must be `io.pullclone.dotclone.uki.*` or
  upstream namespaces.

## Security assertions (phase-driven)

- `my.security.phase` must be 0, 1, or 2.
- Break-glass must be enabled before any phase > 0 when assertions are on.
- Rollouts must be previewed and staged before switching generations.
- Phase >= 1 enforces doas-only escalation and disallows root SSH.
- Phase >= 1 requires a single active locker and Noctalia lock-on-suspend.
- Phase >= 1 enables USBGuard (audit/allow by default) with soft enforcement
  available.
- Phase 1 makes U2F optional; phase 2 makes it required for enrolled users.
- Phase >= 1 enables the UKI bootspec extension for deterministic artifacts.

## Rollout harness and testing

Use the pinned Justfile entry points:

- `just sec-preview <target>`: build + dry-activate via `doas`.
- `just sec-test <target>`: `nixos-rebuild test` via `doas`.
- `just sec-switch <target>`: switch only after preview + test.

Recommended workflow for security changes:

1. `just audit`
2. `just sec-preview <target>`
3. `just sec-test <target>`
4. `just sec-switch <target>` (only after the above are clean)

## Break-glass prerequisites

- Create a break-glass admin user (passworded, non-persistent is fine).
- Add a doas rule for that user.
- Set `my.security.breakglass.enable = true` only after verifying access.
- Store credentials offline with LUKS recovery material.

## Quick recovery (system still boots)

1. Roll back the phase: set `my.security.phase = 0` (or temporarily set
   `my.security.assertions.enable = false`).
2. Run:

   ```bash
   just sec-preview nyx
   just sec-test nyx
   ```

3. If a switch failed, rollback the generation:

   ```bash
   doas nixos-rebuild switch --rollback
   ```

## Offline recovery (system does not boot)

1. Boot a NixOS installer, unlock disks, and `nixos-enter`.
2. Set `my.security.phase = 0` in the flake.
3. Rebuild with `nixos-rebuild test --flake .#<target>`.
4. Re-enable break-glass once stable.

## Locker and U2F notes

- Noctalia is the primary locker; avoid competing lock handlers.
- If PAM changes brick unlock, disable locker PAM snippets and return to
  phase 0 before retrying.
- Keep a LUKS passphrase/keyslot even when experimenting with GPG/TPM flows.

## TPM2 unlock notes

- Installer prompt: enable TPM2 + PIN when using LUKS2 to enroll a TPM token.
- Enrollment is performed via `systemd-cryptenroll` during install and the
  LUKS passphrase remains as a fallback.
- TPM2 PIN is stored in `/etc/nixos/nyxos-install.nix` as an install fact;
  treat it as sensitive and rotate if compromised.

## Rollback drills (recommended before phase 2)

- Stage risky changes with `just sec-test <target>` and reboot to escape.
- Practice booting the previous generation from the bootloader menu.
- For USBGuard recovery, regenerate rules and rebuild:

  ```bash
  doas usbguard generate-policy > /etc/usbguard/rules.conf
  ```

## Boot troubleshooting flags (document only)

- `boot.debug1` / `boot.debug1devices`: verbose initrd diagnostics.
- `boot.shell_on_fail`: unauthenticated shell (last resort; never default).
- `systemd.log_level=debug`: systemd debug output on the kernel cmdline.
