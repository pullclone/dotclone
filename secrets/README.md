# Secrets Directory

This directory stores secret templates and encrypted secret files used by
sops-nix.

- Keep plaintext templates non-sensitive.
- Store encrypted files with a `.sops` suffix (for example,
  `service.yaml.sops`).
- Never commit private key material to this repository.
- Encryption policy and recipients are defined in `../.sops.yaml`.
