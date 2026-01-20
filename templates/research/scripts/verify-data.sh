#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
METADATA="${ROOT}/data/metadata.yaml"
CHECKSUMS="${ROOT}/data/checksums.sha256"
RAW_DIR="${ROOT}/data/raw"

if [ ! -f "${METADATA}" ]; then
  echo "metadata file missing: ${METADATA}" >&2
  exit 1
fi

python - <<'PY' "${METADATA}"
import sys
import yaml

path = sys.argv[1]
required = ["dataset_name", "version", "source_url"]
with open(path, "r", encoding="utf-8") as handle:
    data = yaml.safe_load(handle) or {}

missing = [key for key in required if key not in data or not data[key]]
if missing:
    sys.stderr.write(f"metadata missing required fields {missing} in {path}\n")
    sys.exit(1)

print(f"metadata OK ({path})")
PY

if [ ! -f "${CHECKSUMS}" ]; then
  echo "checksum manifest missing: ${CHECKSUMS}" >&2
  echo "Run: ${ROOT}/scripts/gen-checksums.sh" >&2
  exit 1
fi

if [ ! -d "${RAW_DIR}" ]; then
  echo "raw data directory missing: ${RAW_DIR}" >&2
  exit 1
fi

(
  cd "${ROOT}"
  sha256sum --check "${CHECKSUMS}"
)

echo "checksums OK (${CHECKSUMS})"
