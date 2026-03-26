#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_BASE="${1:-/home/deck/post-proc-fg-research/deploy/vk-layer-mvp}"
LOCAL_OUT_DIR="${ROOT_DIR}/build/linux-amd64/vk-layer-mvp/out"

if [[ ! -f "${LOCAL_OUT_DIR}/libVkLayer_PPFG_mvp.so" ]]; then
  echo "Missing build output. Run scripts/build-linux-amd64.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/_steamdeck_env.sh"

"${ROOT_DIR}/scripts/steamdeck-run.sh" "mkdir -p '${REMOTE_BASE}'"
"${ROOT_DIR}/scripts/steamdeck-scp-to.sh" "${LOCAL_OUT_DIR}/libVkLayer_PPFG_mvp.so" "${REMOTE_BASE}/libVkLayer_PPFG_mvp.so"
"${ROOT_DIR}/scripts/steamdeck-scp-to.sh" "${LOCAL_OUT_DIR}/VkLayer_PPFG_mvp.json" "${REMOTE_BASE}/VkLayer_PPFG_mvp.json"

echo "Deployed to ${STEAMDECK_USER}@${STEAMDECK_HOST}:${REMOTE_BASE}"
