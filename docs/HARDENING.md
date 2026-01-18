# NyxOS Hardening Notes

This document summarizes security hardening defaults and how to adjust
them. All settings are declarative; no mutable state under `/etc`.

## Kernel & Sysctl

- ASLR enabled: `kernel.randomize_va_space = 2`
- Pointer hiding: `kernel.kptr_restrict = 2`
- Dmesg restricted: `kernel.dmesg_restrict = 1`
- Other sysctl live only in `modules/tuning/sysctl.nix`; override via
  modules, not ad-hoc.

## Time Sync (Chrony + NTS)

- Chrony enabled with NTS servers (Cloudflare + Netnod by default).
- Override servers: `my.security.timeSync.ntsServers = [ "time.example" ];`
- Verify: `chronyc sources -v` (look for `NTS`/`PNTS`), `chronyc tracking`.

## Systemd

- Global `DefaultNoNewPrivileges=yes` via manager defaults.
- Override sparingly per unit:

  ```nix
  systemd.services.foo.serviceConfig.NoNewPrivileges = lib.mkForce false;
  ```

## USBGuard

- Declarative policy at `etc/usbguard/rules.conf` (deployed to
  `/etc/usbguard/rules.conf`).
- Generate starter rules: `scripts/usbguard-generate-policy.sh` →
  paste into `etc/usbguard/rules.conf`, rebuild.
- Keep a root/TTY session open while testing to avoid lockout.

## Privilege Escalation

- `doas` enabled for the admin user only (no persist).
- `sudo` disabled.
- Root login disabled (including SSH password auth).

## NVIDIA (Install-Driven)

- Enable via install answers: `nvidia.enable = true`.
- Modes: `desktop`, `laptop-offload`, `laptop-sync`; hybrids require bus
  IDs (`lspci -D`).
- Open kernel module default; set `nvidia.open = false` to force the
  proprietary module.
