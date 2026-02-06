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

## sops-nix workflow

1. Generate and store your age private key on persist storage:
   - `install -d -m 0700 /persist/keys/age`
   - `age-keygen -o /persist/keys/age/keys.txt`
   - `age-keygen -y /persist/keys/age/keys.txt` (public recipient)
2. Replace the example recipient in `.sops.yaml` with your own public
   recipient(s).
3. Enable secret management in NixOS config:

   ```nix
   my.security.secrets = {
     enable = true;
     defaultSopsFile = ./secrets/example.yaml.sops;
   };
   ```

4. Create and edit encrypted files:
   - `cp secrets/example.yaml secrets/my-service.yaml.sops`
   - `sops --encrypt --in-place secrets/my-service.yaml.sops`
   - `sops secrets/my-service.yaml.sops`
5. Declare runtime materialization with `sops.secrets.<name>` as needed.
   sops-nix writes secrets to `/run/secrets/<name>`.

Do not store private keys in this repository. Do not place secrets in
`/etc/nixos/nyxos-install.nix`.

## Runtime placement

Place decrypted secrets under `/run/secrets` during activation or via
sops-nix integration. This keeps secret material out of the repo and
out of the persistent filesystem.

## Secret scanning

The repo includes `scripts/secrets-scan.sh`, which runs gitleaks via
`nix run .#gitleaks`. Use `just secrets-scan` to check the working tree
for accidental plaintext secrets before committing.
