#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/_omfg_layer_impl.sh"

REMOTE_BASE="${1:-${OMFG_LAYER_REMOTE_BASE_DEFAULT}}"
LOCAL_OUT_DIR="${ROOT_DIR}/build/linux-amd64/${OMFG_LAYER_BUILD_SUBDIR}/out"

if [[ ! -f "${LOCAL_OUT_DIR}/${OMFG_LAYER_LIB_BASENAME}" ]]; then
  echo "Missing build output. Run OMFG_LAYER_IMPL=${OMFG_LAYER_IMPL} scripts/build-linux-amd64.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/_steamdeck_env.sh"

"${ROOT_DIR}/scripts/steamdeck-run.sh" "mkdir -p '${REMOTE_BASE}'"
"${ROOT_DIR}/scripts/steamdeck-scp-to.sh" "${LOCAL_OUT_DIR}/${OMFG_LAYER_LIB_BASENAME}" "${REMOTE_BASE}/${OMFG_LAYER_LIB_BASENAME}"
"${ROOT_DIR}/scripts/steamdeck-scp-to.sh" "${LOCAL_OUT_DIR}/${OMFG_LAYER_MANIFEST_BASENAME}" "${REMOTE_BASE}/${OMFG_LAYER_MANIFEST_BASENAME}"

echo "Deployed ${OMFG_LAYER_IMPL} layer to ${STEAMDECK_USER}@${STEAMDECK_HOST}:${REMOTE_BASE}"
