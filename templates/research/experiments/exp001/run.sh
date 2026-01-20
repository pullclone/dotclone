#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="${1:-"${PWD}/runs/exp001"}"
METADATA="${2:-"${ROOT}/data/metadata.yaml"}"
EXP_ID="$(basename "${RUN_DIR}")"

mkdir -p "${RUN_DIR}"

python "${ROOT}/src/your_code.py" \
  --exp "${EXP_ID}" \
  --metadata "${METADATA}" \
  --run-dir "${RUN_DIR}"
