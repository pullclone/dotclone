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
- New preset selector: set `my.ssh.profile = "hardened"` or `"developer"` for
  secure defaults. Use `my.ssh.profile = "custom"` to manage
  `my.ssh.client.*` directly.

### SSH host key pinning (git providers & custom hosts)

NyxOS supports **declarative SSH host key pinning** via `programs.ssh.knownHosts` to prevent MITM attacks.
Pins are **opt-in** and split into two categories:

Enabling `my.ssh.knownHosts.enable` only permits trust roots to be declared.
No host keys or certificate authorities are installed unless a bundle or manual
pin is explicitly enabled.

For host CA scaffolding (off by default), see `docs/SSH_CA_WORKFLOW.md`.

#### Built-in opt-in bundles

If enabled (`my.ssh.knownHosts.enable = true`) and selected via features, NyxOS provides a maintained bundle for common public Git hosts:

- GitHub
- GitLab
- Bitbucket
- Codeberg

These are enabled by adding `"git-hosts"` to `my.ssh.client.features`.

```nix
my.ssh = {
  knownHosts.enable = true;
  client.features = [ "git-hosts" ];
};
```

These entries are managed centrally and updated deliberately.

#### Manual pinning (Azure DevOps, AWS CodeCommit, SourceHut, self-hosted)

Some providers do **not** publish a single global SSH host key, or publish **fingerprints only**.
For these, NyxOS intentionally does **not** ship pre-pinned keys.

Use `my.ssh.hostKeys` to add your own verified pins.

##### Azure DevOps

- Host: `ssh.dev.azure.com`
- Verify the ed25519 host key fingerprint **before pinning**:

```
SHA256:ohD8VZEXGWo6Ez8GSEJQ9WpafgLFsOfLOtGGQCQo6Og
```

Verification workflow:

```bash
ssh-keyscan -t ed25519 ssh.dev.azure.com > /tmp/azure.key
ssh-keygen -lf /tmp/azure.key
```

Compare the SHA-256 fingerprint, then pin the key.

##### AWS CodeCommit

AWS CodeCommit uses **regional SSH endpoints** with **region-specific fingerprints**.

- Consult AWS documentation for your region
- Verify the fingerprint of the key returned by `ssh-keyscan`
- Pin only after verification

##### SourceHut, Apache Allura, self-hosted Git

These are **self-hosted or federated** services.

- Obtain host keys directly from the service
- Verify fingerprints out-of-band
- Pin explicitly using `my.ssh.hostKeys`

##### Example manual pin

```nix
my.ssh.hostKeys = {
  "ssh.dev.azure.com" = {
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...";
  };
};
```

**Important:** Host key pins are part of the system trust model.
Only add keys after independent verification.

##### Helper: generate a Nix snippet

To add new SSH trust pins, use `scripts/ssh-keyscan-to-nix.sh`,
verify the fingerprint out-of-band, and paste the result into
a known-hosts bundle or `my.ssh.hostKeys`.
