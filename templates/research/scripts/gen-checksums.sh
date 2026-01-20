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

mapfile -t files < <(find "${RAW_DIR}" -type f | sort)

if [ "${#files[@]}" -eq 0 ]; then
  echo "no files found under ${RAW_DIR}; nothing to checksum" >&2
  exit 1
fi

(
  cd "${ROOT}"
  printf '%s\n' "${files[@]}" | xargs -r sha256sum > "${OUT_FILE}"
)

echo "checksums written to ${OUT_FILE}"
