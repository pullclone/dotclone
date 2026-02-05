# Operating NyxOS (cheat sheet)

Daily commands and checks for building, switching, and debugging the
system.

## Inspect config values (debugging)

Use `nixos-option` to see the final merged value of any option:

```bash
nixos-option --flake .#nyx programs.niri.enable
# or evaluate another output:
nixos-option --flake .#nyx-latency-lfx-off services.pipewire.enable
```

For ad-hoc evaluation, `nix eval .#nixosConfigurations.nyx.config.<path>`
also works.

## Build / check

```bash
nix flake check .
just audit
just build
```

## WSL note

On NixOS-WSL, `/run/user/$UID` may be missing or unwritable. Prefer the
guarded `just check` / `just lint` recipes, or set:

```bash
export XDG_RUNTIME_DIR="/tmp/xdg-runtime-$UID"
install -d -m 0700 "$XDG_RUNTIME_DIR"
```

## Switch (choose one)

### Using flake output directly (recommended)

```bash
sudo nixos-rebuild switch --flake .#nyx-balanced-lfx-on
sudo nixos-rebuild test --flake .#nyx-latency-lfx-off
sudo nixos-rebuild boot --flake .#nyx-throughput-lfx-on
```

### Using `just` convenience targets

```bash
just switch-balanced-lfx-on
just switch-latency-lfx-off
```

## When testing risky changes

- Prefer `nixos-rebuild test` before `switch`.
- To see what would change without applying, use the dry-activation
  support described in the NixOS manual (`switch-to-configuration`
  internals).

## End state checklist (all green)

- [ ] Single owner for Niri/Noctalia options (no collisions)
- [ ] Five official profiles, ten explicit flake outputs, plus `nyx`
  alias
- [ ] No impure build pathways required
- [ ] `just audit` is strict and deterministic
- [ ] `scripts/audit-repo.sh` enforces reproducibility contracts
- [ ] Docs explain profiles, outputs, linting, and operations
- [ ] CI runs `just audit` + `nix flake check .`
