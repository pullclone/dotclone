# Preflight Guide

This document explains what `just audit` checks and how to interpret failures.

## What `just audit` runs

- `just check-nixfmt`: `nixfmt-tree --check .` must report no changes.
- `just shellcheck-strict`: strict shellcheck on critical scripts
  (audit/pre-install/preflight).
- `scripts/audit-repo.sh`: contract checks for the flake and repo layout.
- `scripts/check-docs.sh`: required documentation presence (gating).
- `just shellcheck-advisory`: non-blocking shellcheck across all scripts.

## What `scripts/audit-repo.sh` enforces

- `/etc/nixos/nyxos-install.nix` only referenced in
  `modules/core/install-answers.nix`.
- `boot.kernel.sysctl` defined only in `modules/tuning/sysctl.nix` or
  approved ZRAM/system profiles.
- `builtins.fetchGit` is forbidden.
- `fetchTarball`/`fetchzip`/`fetchgit` must include a hash.
- Niri and Noctalia ownership rules are respected.
- No plaintext key material in the repo.
- No `/nix/store` key material references.

## Formatting expectations

- Nix formatting is enforced with `nixfmt-tree`.
- Use `just fmt-nix` to format, `just check-nixfmt` to verify.

## ShellCheck policy

- Strict (gating): audit/preflight/pre-install scripts.
- Advisory (non-blocking): all `scripts/*.sh`.
- Suppressions must be local with a one-line rationale.

## SSH secrets (optional)

- If you use sops/agenix, point `identityFile` to the secret path (for example,
  `identityFile = \"${config.sops.secrets.<name>.path}\";`).
- Never store private key material in the repo or the Nix store.

## Installer SSH inputs

- Installer answers set `my.ssh.client.profile`, `my.ssh.client.features`,
  and `my.ssh.knownHosts.enable`.
- System trust roots live in NixOS `programs.ssh.knownHosts`; client UX lives
  in Home Manager via the SSH templates.

## Git host pins (opt-in)

- Enable by adding `"git-hosts"` to `my.ssh.client.features` and leaving
  `my.ssh.knownHosts.enable = true`.
- Bundle lives at `templates/ssh/known-hosts/git-hosts.nix` (ed25519 pins).
- Host keys can rotate; refresh the bundle when upstream changes.
- Verify keys against provider docs:
  - https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/githubs-ssh-key-fingerprints
  - https://docs.gitlab.com/ee/user/gitlab_com/#ssh-host-keys-fingerprints
  - https://bitbucket.org/site/ssh
  - https://docs.codeberg.org/security/ssh-fingerprint/
- Codeberg publishes fingerprints only; ensure the pinned key matches the
  official fingerprint list when updating.
- Providers without published public keys must be added via
  `my.ssh.knownHosts.pins` once official keys are available.
  - Currently missing: Azure DevOps, AWS CodeCommit, SourceHut, Apache Allura.
