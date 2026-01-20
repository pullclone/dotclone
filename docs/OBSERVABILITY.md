# Observability: AIDE & Lynis (Phase-Safe)

## AIDE (integrity)

- Toggle: `my.security.aide.enable` (phase ≥0; defaults off)
- Config: `/etc/aide.conf` excludes `/nix/store`, `/tmp`, `/run`, `/dev`,
  `/proc`, `/sys`, and stores DB under `/var/lib/nyxos/aide`.
- Reports: `/var/log/nyxos/aide/aide-check-<timestamp>.log`
- Units:
  - `aide-init.service` (manual, oneshot) — creates the initial DB
  - `aide-check.service` (manual, oneshot) — runs check, writes report
  - `aide-check.timer` (weekly, persistent)
- Helpers:
  - `just aide-init` — `doas systemctl start aide-init.service`
  - `just aide-check` — `doas systemctl start aide-check.service`

Recommended rollout:

1. Enable AIDE, rebuild with `just sec-preview/test`.
2. Run `just aide-init` once.
3. Let the weekly timer run; spot-check reports under
   `/var/log/nyxos/aide/`.

## Lynis

- Toggle: `my.security.lynis.enable` (phase ≥0; defaults off)
- Reports: `/var/log/nyxos/lynis/<timestamp>/lynis.log` and `report.dat`
- Units:
  - `lynis-audit.service` (manual, oneshot)
  - `lynis-audit.timer` (weekly, optional toggle `my.security.lynis.timer.enable`)
- Helpers:
  - `just lynis` — `doas systemctl start lynis-audit.service`
  - `just lynis-report` — print latest report path and tail the summary

Recommended rollout: enable Lynis, rebuild, run `just lynis`, and review
the report directory.
