#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
: "${OMFG_LAYER_IMPL:=rust}"

if [[ "${OMFG_LAYER_IMPL}" != "rust" ]]; then
  echo "Present-timing validation currently targets the Rust layer only." >&2
  exit 1
fi

export STEAMDECK_PASS="${STEAMDECK_PASS:?Set STEAMDECK_PASS}"

OMFG_LAYER_IMPL="${OMFG_LAYER_IMPL}" "${ROOT_DIR}/scripts/build-linux-amd64.sh"
OMFG_LAYER_IMPL="${OMFG_LAYER_IMPL}" "${ROOT_DIR}/scripts/deploy-steamdeck-layer.sh"

OMFG_LAYER_IMPL="${OMFG_LAYER_IMPL}" \
OMFG_LAYER_MODE=multi-blend \
OMFG_MULTI_BLEND_COUNT=3 \
OMFG_PRESENT_TIMING=1 \
OMFG_PRESENT_WAIT=1 \
OMFG_PRESENT_WAIT_TIMEOUT_NS=5000000000 \
OMFG_VKCUBE_COUNT=20 \
OMFG_VKCUBE_TIMEOUT_SEC=40 \
OMFG_VKCUBE_ARTIFACT_SUFFIX=present-timing \
"${ROOT_DIR}/scripts/test-steamdeck-vkcube.sh"

LOG_PATH="${ROOT_DIR}/artifacts/steamdeck/rust/vkcube/multi-blend-present-timing/omfg-vkcube.log"

python3 - <<'PY' "${LOG_PATH}"
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text().splitlines()
needles = {
    'device_extensions': 'vkCreateDevice appended timing extensions',
    'device_support': 'vkCreateDevice ok; gpu=',
    'present_wait': 'present wait result;',
}
missing = [name for name, needle in needles.items() if not any(needle in line for line in text)]
if missing:
    raise SystemExit(f"Missing timing markers in {path}: {', '.join(missing)}")

print(f"present timing validation markers found in {path}")
for needle in ['present wait result;', 'present timing refresh;', 'present timing sample;']:
    matches = [line for line in text if needle in line]
    if matches:
        print(f"--- {needle} ---")
        for line in matches[:10]:
            print(line)
PY

echo "Present timing Steam Deck validation passed for ${OMFG_LAYER_IMPL}"
