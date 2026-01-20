#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXP_ID="${1:-exp001}"
EXP_DIR="${ROOT}/experiments/${EXP_ID}"
EXP_SCRIPT="${EXP_DIR}/run.sh"
RUN_DIR="${PWD}/runs/${EXP_ID}"
METADATA="${ROOT}/data/metadata.yaml"

"${ROOT}/scripts/verify-data.sh"

if [ ! -f "${EXP_SCRIPT}" ]; then
  echo "experiment script not found: ${EXP_SCRIPT}" >&2
  exit 1
fi

LOG_FILE="$("${ROOT}/scripts/log-run.sh" "${EXP_ID}" "${RUN_DIR}" "${METADATA}")"

(
  cd "${EXP_DIR}"
  bash "${EXP_SCRIPT}" "${RUN_DIR}" "${METADATA}"
) | tee -a "${LOG_FILE}"

echo "run logged to ${LOG_FILE}"
