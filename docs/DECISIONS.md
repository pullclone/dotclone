# Decision Register (05 Feb 2026)

1. **GitHub Actions pinning:** Pin all third-party actions by full commit SHA and add Dependabot to keep them updated.
2. **OIDC token exposure:** Only grant `id-token` on trusted pushes (e.g. `main`); pull-requests run with read-only permissions.
3. **Secrets handling:** Use `sops-nix` (age) for secrets, add pre-commit secret scanning, and ensure installers never write secret material to disk or the repo.
4. **Privilege escalation:** Main branch uses `doas` as primary and keeps `sudo` installed but disabled by default; a separate `variant/with-sudo` branch enables both. Introduce a `my.security.access.sudoFallback.enable` option.
5. **Installer support:** Support NixOS bare metal & VMs; detect and bail on WSL; add offline detection and keep network-dependent features optional.
