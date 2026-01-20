# Release Provenance (NyxOS)

This snippet standardises how to capture and cite a NyxOS build or
switch, keeping provenance minimal and reproducible.

## How to Cite a Build

Record the following for any system target (e.g.
`nyx-throughput-lfx-off`):

- **Target**: `nyx-<profile>-lfx-<on|off>`
- **Git**: `git rev-parse HEAD` + note if dirty
- **Lock hash**: `sha256sum flake.lock | cut -d' ' -f1`
- **Nixpkgs rev**: `nix flake metadata --json | jq -r '.locks.nodes.nixpkgs.locked.rev'`
- **NixOS version**: `nixos-version` (on a switched system)

## How to Reproduce the Exact Build

```bash
# capture provenance (from repo root)
git rev-parse HEAD
git diff --quiet || echo "dirty tree"
sha256sum flake.lock | cut -d' ' -f1
nix flake metadata --json | jq -r '.locks.nodes.nixpkgs.locked.rev'

# build and switch the exact target (example)
TARGET=nyx-balanced-lfx-on
nix build .#nixosConfigurations.${TARGET}.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#${TARGET}
```

Tip: include the command output alongside release notes or run logs so
others can rebuild with the same inputs.
