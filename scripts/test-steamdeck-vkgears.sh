#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_BASE="${1:-/home/deck/post-proc-fg-research/deploy/vk-layer-mvp}"
MODE="${PPFG_LAYER_MODE:-passthrough}"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/steamdeck/vkgears/${MODE}"

mkdir -p "${ARTIFACT_DIR}"

REMOTE_SCRIPT=$(cat <<EOF
set -euo pipefail
mkdir -p ${REMOTE_BASE}
rm -f ${REMOTE_BASE}/ppfg-vkgears.log ${REMOTE_BASE}/vkgears.stdout
set -a
source /run/user/1000/gamescope-environment
set +a
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1000
export XAUTHORITY=\$(ls -1 /run/user/1000/xauth_* | head -1)
export DISABLE_GAMESCOPE_WSI=1
export ENABLE_PPFG_MVP=1
export PPFG_LAYER_MODE=${MODE}
export PPFG_LAYER_LOG_FILE=${REMOTE_BASE}/ppfg-vkgears.log
export VK_LAYER_PATH=${REMOTE_BASE}
export VK_INSTANCE_LAYERS=VK_LAYER_PPFG_mvp
printf 'RUN display=%s xauthority=%s mode=%s\n' "\$DISPLAY" "\$XAUTHORITY" "\$PPFG_LAYER_MODE"
timeout 10s vkgears > ${REMOTE_BASE}/vkgears.stdout 2>&1 || status=\$?
printf 'VKGEARS_STATUS=%s\n' "\${status:-0}"
ls -lah ${REMOTE_BASE}
printf '\n--- vkgears.stdout ---\n'
sed -n '1,200p' ${REMOTE_BASE}/vkgears.stdout || true
printf '\n--- ppfg-vkgears.log ---\n'
sed -n '1,240p' ${REMOTE_BASE}/ppfg-vkgears.log || true
EOF
)

"${ROOT_DIR}/scripts/steamdeck-run.sh" "${REMOTE_SCRIPT}"
"${ROOT_DIR}/scripts/steamdeck-scp-from.sh" "${REMOTE_BASE}/vkgears.stdout" "${ARTIFACT_DIR}/vkgears.stdout"
"${ROOT_DIR}/scripts/steamdeck-scp-from.sh" "${REMOTE_BASE}/ppfg-vkgears.log" "${ARTIFACT_DIR}/ppfg-vkgears.log"

echo "Artifacts saved under ${ARTIFACT_DIR}"
