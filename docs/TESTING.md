# Testing & VM Smoke Harness

## VM smoke tests (per flake output)

Use the VM harness to boot any finite output without touching the host:

```bash
just vm nyx
# or another output, e.g.:
just vm nyx-balanced-lfx-off
```

This builds the QEMU VM derivation and provides a runner at
`./result/bin/run-<name>-vm`. If `doas` is available, it uses
`nixos-rebuild build-vm`; otherwise it falls back to `nix build .#...vm`.

To clean a stale disk:

```bash
just vm-clean nyx
```

(The manual notes that VM settings don’t apply if a qcow2 already
exists; remove it before rerunning.)

### Notes

- VM images inherit the flake output’s users; if you need a temporary
  login for testing, use a dedicated VM specialization rather than
  modifying real outputs.
- Use `nixos-option` inside the VM for quick config inspection.
