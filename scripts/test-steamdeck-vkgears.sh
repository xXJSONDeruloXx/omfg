#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${OMFG_LAYER_MODE:-passthrough}"

# shellcheck disable=SC1091
source "${ROOT_DIR}/scripts/_omfg_layer_impl.sh"

REMOTE_BASE="${1:-${OMFG_LAYER_REMOTE_BASE_DEFAULT}}"
ARTIFACT_DIR="${ROOT_DIR}/${OMFG_LAYER_ARTIFACT_ROOT_REL}/vkgears/${MODE}"

mkdir -p "${ARTIFACT_DIR}"

REMOTE_SCRIPT=$(cat <<EOF
set -euo pipefail
mkdir -p ${REMOTE_BASE}
rm -f ${REMOTE_BASE}/omfg-vkgears.log ${REMOTE_BASE}/vkgears.stdout
set -a
source /run/user/1000/gamescope-environment
set +a
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1000
export XAUTHORITY=\$(ls -1 /run/user/1000/xauth_* | head -1)
export DISABLE_GAMESCOPE_WSI=1
export ${OMFG_LAYER_ENABLE_ENV}=1
export OMFG_LAYER_MODE=${MODE}
export OMFG_LAYER_LOG_FILE=${REMOTE_BASE}/omfg-vkgears.log
export OMFG_BFI_PERIOD=${OMFG_BFI_PERIOD:-}
export OMFG_MULTI_SWAPCHAIN_MAX_GENERATED_FRAMES=${OMFG_MULTI_SWAPCHAIN_MAX_GENERATED_FRAMES:-}
export OMFG_PRESENT_TIMING=${OMFG_PRESENT_TIMING:-}
export OMFG_PRESENT_WAIT=${OMFG_PRESENT_WAIT:-}
export OMFG_PRESENT_WAIT_TIMEOUT_NS=${OMFG_PRESENT_WAIT_TIMEOUT_NS:-}
export VK_LAYER_PATH=${REMOTE_BASE}
export VK_INSTANCE_LAYERS=${OMFG_LAYER_NAME}
printf 'RUN impl=%s display=%s xauthority=%s mode=%s layer=%s multi_swapchain_cap=%s present_timing=%s present_wait=%s present_wait_timeout_ns=%s\n' "${OMFG_LAYER_IMPL}" "\$DISPLAY" "\$XAUTHORITY" "\$OMFG_LAYER_MODE" "\$VK_INSTANCE_LAYERS" "${OMFG_MULTI_SWAPCHAIN_MAX_GENERATED_FRAMES:-default}" "${OMFG_PRESENT_TIMING:-default}" "${OMFG_PRESENT_WAIT:-default}" "${OMFG_PRESENT_WAIT_TIMEOUT_NS:-default}"
timeout 10s vkgears > ${REMOTE_BASE}/vkgears.stdout 2>&1 || status=\$?
printf 'VKGEARS_STATUS=%s\n' "\${status:-0}"
ls -lah ${REMOTE_BASE}
printf '\n--- vkgears.stdout ---\n'
sed -n '1,200p' ${REMOTE_BASE}/vkgears.stdout || true
printf '\n--- omfg-vkgears.log ---\n'
sed -n '1,240p' ${REMOTE_BASE}/omfg-vkgears.log || true
EOF
)

"${ROOT_DIR}/scripts/steamdeck-run.sh" "${REMOTE_SCRIPT}"
"${ROOT_DIR}/scripts/steamdeck-scp-from.sh" "${REMOTE_BASE}/vkgears.stdout" "${ARTIFACT_DIR}/vkgears.stdout"
"${ROOT_DIR}/scripts/steamdeck-scp-from.sh" "${REMOTE_BASE}/omfg-vkgears.log" "${ARTIFACT_DIR}/omfg-vkgears.log"

echo "Artifacts saved under ${ARTIFACT_DIR}"
