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

## Crash-resistant flake checks (IO and memory pressure)

Use the stable wrapper when `nix flake check` is failing under heavy
load:

```bash
just flake-check-stable
```

The wrapper (`scripts/flake-check-stable.sh`) applies explicit tuning
flags that were effective in prior failing runs:

- `--option max-jobs 1` (serialize build/eval pressure)
- `--option cores 1` (reduce per-builder CPU+RAM demand)
- `--option keep-outputs false` (lower retained store paths)
- `--option keep-derivations false` (lower retained metadata/store growth)
- `--option fallback true` (retry around transient substituter misses)
- `--option connect-timeout 15` (fail fast on stalled network paths)

You can override these with environment variables:

```bash
NIX_FLAKE_CHECK_MAX_JOBS=1 \
NIX_FLAKE_CHECK_CORES=1 \
NIX_FLAKE_CHECK_KEEP_OUTPUTS=false \
NIX_FLAKE_CHECK_KEEP_DERIVATIONS=false \
just flake-check-stable
```

### Failure cause matrix (observed patterns)

- Daemon socket permission errors:
  `cannot connect to socket ... daemon-socket ... Operation not permitted`
  usually means sandbox/permission boundaries blocked Nix daemon access.
- Disk/store pressure:
  `No space left on device` usually indicates `/nix/store` churn; reduced
  retention flags and garbage collection were effective.
- Memory pressure / OOM:
  `Cannot allocate memory`, `oom-killer`, `exit code 137` mapped to overly
  concurrent checks; serialized flags were effective.
- Network/substituter instability:
  timeout/TLS/download failures improved with `fallback=true`, conservative
  timeout, and retry.

On failure, the wrapper prints a likely-cause summary and log tail, and
writes a full timestamped log under `/tmp` by default.

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

## Security timer frequency knobs

Both integrity/audit modules expose timer frequency controls:

- `my.security.aide.frequency = "daily" | "weekly" | "monthly" | "off"`
- `my.security.lynis.frequency = "daily" | "weekly" | "monthly" | "off"`

Mapping is direct to `systemd.timers.<name>.timerConfig.OnCalendar`.
Using `"off"` disables only the timer; service units remain available
for manual runs.

Lynis also still requires `my.security.lynis.timer.enable = true` for
periodic execution.

Recommended laptop defaults (lower battery + IO impact):

- `my.security.aide.frequency = "weekly"`
- `my.security.lynis.frequency = "monthly"` (with
  `my.security.lynis.timer.enable = true`)

## End state checklist (all green)

- [ ] Single owner for Niri/Noctalia options (no collisions)
- [ ] Five official profiles, ten explicit flake outputs, plus `nyx`
  alias
- [ ] No impure build pathways required
- [ ] `just audit` is strict and deterministic
- [ ] `scripts/audit-repo.sh` enforces reproducibility contracts
- [ ] Docs explain profiles, outputs, linting, and operations
- [ ] CI runs `just audit` + `nix flake check .`
