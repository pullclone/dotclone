# Secrets Handling

## Policy

All secrets must be encrypted with sops/age and must not be committed in
plaintext. Do not place secrets directly in the repository or in
installation answers. Runtime secrets should live under `/run/secrets`.

## Bootstrapping age

1. Generate an age key (example):
   - `age-keygen -o ~/.config/sops/age/keys.txt`
2. Export the public key and configure `sops-nix` to use it.
3. Encrypt secrets with sops and ensure only encrypted files are tracked.

## Runtime placement

Place decrypted secrets under `/run/secrets` during activation or via
sops-nix integration. This keeps secret material out of the repo and
out of the persistent filesystem.

## Secret scanning

The repo includes `scripts/secrets-scan.sh`, which runs gitleaks via
`nix run .#gitleaks`. Use `just secrets-scan` to check the working tree
for accidental plaintext secrets before committing.
