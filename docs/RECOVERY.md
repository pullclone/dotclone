# Recovery & Break-Glass

NyxOS ships with `sudo` disabled and expects `doas` plus a documented
break-glass path before raising hardening phases. Root SSH login stays
off; keep at least one strong-password admin in the `wheel` group.

## Prerequisites

- Set `my.security.breakglass.enable = true` once a break-glass account
  and `doas` rule are in place (non-persistent, passworded).
- Record the break-glass user, password policy, and where the doas rule
  lives. Store this offline with the LUKS recovery material.

## Quick recovery (system still boots)

1. **Roll back the phase**: set `my.security.phase = 0` (or temporarily
   `my.security.assertions.enable = false`) and run:

   ```bash
   just sec-preview nyx
   just sec-test nyx
   ```

2. **Use the previous generation** if a switch failed:

   ```bash
   doas nixos-rebuild switch --rollback
   ```

3. **Verify controls**: `nixos-option my.security.phase` and confirm
   `doas` works for the admin user.

## Offline recovery (won't boot cleanly)

1. Boot a NixOS installer, unlock disks, and `nixos-enter` the root.
2. Edit the flake to `my.security.phase = 0` and keep
   `my.security.assertions.enable = true` once stable.
3. Rebuild with `nixos-rebuild test --flake .#<target>` and re-enable
   the break-glass account.

## Locker & U2F notes

- Noctalia is the primary locker; if a PAM change bricks unlock, disable
  the locker’s PAM snippet and return to phase 0 before retrying.
- Treat Trezor One as a userland authenticator (U2F/SSH agent). Do not
  depend on it for initrd/LUKS unlock until a minimal, tested flow is
  proven.

## Rollback drills (recommended before phase 2)

- Stage risky changes with `just sec-test <target>`; reboot escapes the
  staged generation.
- Practice booting the previous generation from the bootloader menu.
- Keep a console path for USBGuard soft-enforce recovery:
  `doas usbguard generate-policy > /etc/usbguard/rules.conf` then
  rebuild.

## Boot troubleshooting flags (document, don’t enable by default)

- `boot.debug1` / `boot.debug1devices` — verbose initrd diagnostics.
- `boot.shell_on_fail` — **unauthenticated**, use only as a last resort
  during recovery, never enable by default.
- `systemd.log_level=debug` — kernel cmdline for systemd debug output.
