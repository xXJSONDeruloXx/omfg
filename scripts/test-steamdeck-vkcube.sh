#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_BASE="${1:-/home/deck/post-proc-fg-research/deploy/vk-layer-mvp}"
MODE="${PPFG_LAYER_MODE:-passthrough}"
ARTIFACT_DIR="${ROOT_DIR}/artifacts/steamdeck/vkcube/${MODE}"

mkdir -p "${ARTIFACT_DIR}"

REMOTE_SCRIPT=$(cat <<EOF
set -euo pipefail
mkdir -p ${REMOTE_BASE}
rm -f ${REMOTE_BASE}/ppfg-vkcube.log ${REMOTE_BASE}/vkcube.stdout
set -a
source /run/user/1000/gamescope-environment
set +a
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1000
export XAUTHORITY=\$(ls -1 /run/user/1000/xauth_* | head -1)
export DISABLE_GAMESCOPE_WSI=1
export ENABLE_PPFG_MVP=1
export PPFG_LAYER_MODE=${MODE}
export PPFG_LAYER_LOG_FILE=${REMOTE_BASE}/ppfg-vkcube.log
export VK_LAYER_PATH=${REMOTE_BASE}
export VK_INSTANCE_LAYERS=VK_LAYER_PPFG_mvp
printf 'RUN display=%s xauthority=%s mode=%s\n' "\$DISPLAY" "\$XAUTHORITY" "\$PPFG_LAYER_MODE"
timeout 20s vkcube --c 120 --suppress_popups --wsi xcb > ${REMOTE_BASE}/vkcube.stdout 2>&1 || status=\$?
printf 'VCUBE_STATUS=%s\n' "\${status:-0}"
ls -lah ${REMOTE_BASE}
printf '\n--- vkcube.stdout ---\n'
sed -n '1,200p' ${REMOTE_BASE}/vkcube.stdout || true
printf '\n--- ppfg-vkcube.log ---\n'
sed -n '1,240p' ${REMOTE_BASE}/ppfg-vkcube.log || true
EOF
)

"${ROOT_DIR}/scripts/steamdeck-run.sh" "${REMOTE_SCRIPT}"
"${ROOT_DIR}/scripts/steamdeck-scp-from.sh" "${REMOTE_BASE}/vkcube.stdout" "${ARTIFACT_DIR}/vkcube.stdout"
"${ROOT_DIR}/scripts/steamdeck-scp-from.sh" "${REMOTE_BASE}/ppfg-vkcube.log" "${ARTIFACT_DIR}/ppfg-vkcube.log"

echo "Artifacts saved under ${ARTIFACT_DIR}"
