# Upgrading NyxOS Flake Inputs

Use the maintainer upgrade workflow to update flake inputs and run all required
validation gates in one path.

## Standard flow

From the repo root:

```bash
just upgrade
```

`just upgrade` runs `scripts/upgrade.sh`, which:

1. Prints git status and refuses to continue on a dirty tree.
2. Runs `nix flake update`.
3. Runs validation gates in the pinned toolchain:
   - `just audit`
   - `just test-strict`
   - `nix flake check .`
4. Prints `git diff --stat flake.lock`.
5. Reminds you to review `system.stateVersion` and `home.stateVersion` before
   committing lockfile updates.

Useful flags:

```bash
scripts/upgrade.sh --force
scripts/upgrade.sh --dry-run
```

## Rollback options

If you have not committed upgrade changes:

```bash
git restore flake.lock
```

If you already committed and merged:

1. Revert the upgrade commit:
   ```bash
   git revert <upgrade-commit>
   ```
2. Rebuild with the reverted revision.

If a deployed system needs runtime rollback:

```bash
sudo nixos-rebuild switch --rollback
```

## State version guidance

`system.stateVersion` and `home.stateVersion` are migration compatibility
markers, not routine package version knobs.

- Do not bump them automatically during lockfile updates.
- Bump only when intentionally adopting new defaults/migrations from release
  notes.
- Test state version bumps on non-critical systems first.

## Expected breakpoints during upgrades

- Home Manager module option renames/removals.
- NixOS module option renames/deprecations.
- Package removals or attribute moves in nixpkgs.
- Service default hardening changes that require explicit config.
- Kernel/driver regressions that affect specific hardware profiles.
