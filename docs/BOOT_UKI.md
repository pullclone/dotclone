# UKI & Bootspec Extensions

- Namespace: `io.pullclone.dotclone.uki.*` (unique per bootspec
  guidance)
- Enabled when `my.security.phase >= 1` and UKI boot is selected.
- Extensions:
  - `io.pullclone.dotclone.uki.osRelease` → `/etc/os-release`
  - `io.pullclone.dotclone.uki.hostName`
  - `io.pullclone.dotclone.uki.profile` (install profile)
  - `io.pullclone.dotclone.uki.systemProfile` (flake system profile)
- Deterministic output: `system.build.bootspec` (used by
  `just build-uki`).
- No key enrollment/signing yet; this is groundwork only.
- Preview activation churn safely: `just dry-activate <target>` builds
  the closure and runs `switch-to-configuration dry-activate`.
