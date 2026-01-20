#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RAW_DIR="${ROOT}/data/raw"
OUT_FILE="${ROOT}/data/checksums.sha256"

if [ ! -d "${RAW_DIR}" ]; then
  echo "missing data directory: ${RAW_DIR}" >&2
  echo "Add raw files under data/raw/ then rerun." >&2
  exit 1
fi

file_count="$(find "${RAW_DIR}" -type f | wc -l | tr -d ' ')"

if [ "${file_count}" -eq 0 ]; then
  echo "no files found under ${RAW_DIR}; nothing to checksum" >&2
  exit 1
fi

(
  cd "${ROOT}"
  find "data/raw" -type f -print0 | sort -z | xargs -0 sha256sum > "${OUT_FILE}"
)

echo "checksums written to ${OUT_FILE}"
