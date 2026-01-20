#!/usr/bin/env bash
set -euo pipefail

log_dir="/var/log/nyxos/lynis"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root (use doas/sudo): $0" >&2
  exit 1
fi

ts=$(date -Iseconds)
outdir="${log_dir}/${ts}"
mkdir -p "$outdir"
lynis audit system --quiet --logfile "$outdir/lynis.log" --report-file "$outdir/report.dat"
echo "Lynis report: $outdir"
