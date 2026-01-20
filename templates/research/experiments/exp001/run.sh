#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN_DIR="${1:-"${PWD}/runs/exp001"}"
METADATA="${2:-"${ROOT}/data/metadata.yaml"}"
EXP_ID="$(basename "${RUN_DIR}")"

mkdir -p "${RUN_DIR}"

python - <<'PY'
import platform

def optional_import(name):
    try:
        module = __import__(name)
        version = getattr(module, "__version__", "unknown")
        return f"{name}={version}"
    except ImportError:
        return f"{name}=not-installed"

print("python_version=" + platform.python_version())
print(optional_import("yaml"))
print(optional_import("numpy"))
PY

python "${ROOT}/src/your_code.py" \
  --exp "${EXP_ID}" \
  --metadata "${METADATA}" \
  --run-dir "${RUN_DIR}"
