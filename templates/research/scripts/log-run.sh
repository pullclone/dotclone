#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXP_ID="${1:-exp001}"
RUN_DIR="${2:-"${PWD}/runs/${EXP_ID}"}"
METADATA_PATH="${3:-"${ROOT}/data/metadata.yaml"}"

mkdir -p "${RUN_DIR}"

timestamp="$(date -Iseconds)"
log_file="${RUN_DIR}/${timestamp}.log"
git_rev="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"
flake_lock_hash="$(sha256sum "${ROOT}/flake.lock" 2>/dev/null | awk '{print $1}' || echo "missing")"

{
  echo "timestamp: ${timestamp}"
  echo "experiment: ${EXP_ID}"
  echo "metadata: ${METADATA_PATH}"
  echo "git_rev: ${git_rev}"
  echo "flake_lock_sha256: ${flake_lock_hash}"
  echo "run_dir: ${RUN_DIR}"
} | tee "${log_file}" >&2

printf '%s\n' "${log_file}"
