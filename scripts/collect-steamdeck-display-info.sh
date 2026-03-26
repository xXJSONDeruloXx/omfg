#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SUFFIX="${1:-latest}"
REMOTE_BASE="/home/deck/post-proc-fg-research/display-info/${SUFFIX}"
ARTIFACT_ROOT="${ROOT_DIR}/artifacts/steamdeck/display-info"
ARTIFACT_DIR="${ARTIFACT_ROOT}/${SUFFIX}"

mkdir -p "${ARTIFACT_ROOT}"
rm -rf "${ARTIFACT_DIR}"

REMOTE_SCRIPT=$(cat <<EOF
set -euo pipefail
mkdir -p ${REMOTE_BASE}
rm -f ${REMOTE_BASE}/summary.txt ${REMOTE_BASE}/xrandr.txt ${REMOTE_BASE}/drm_modes.txt ${REMOTE_BASE}/modetest.txt ${REMOTE_BASE}/drm_info.txt ${REMOTE_BASE}/vulkan_display_timing.txt
set -a
source /run/user/1000/gamescope-environment
set +a
export DISPLAY=:0
export XDG_RUNTIME_DIR=/run/user/1000
export XAUTHORITY=\$(ls -1 /run/user/1000/xauth_* | head -1)
{
  echo "timestamp_utc=\$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "hostname=\$(uname -n)"
  echo "kernel=\$(uname -srmo)"
  echo "display=\$DISPLAY"
  echo "xauthority=\$XAUTHORITY"
  echo
  echo "--- gamescope-environment ---"
  cat /run/user/1000/gamescope-environment || true
} > ${REMOTE_BASE}/summary.txt

{
  echo "--- xrandr --listactivemonitors ---"
  xrandr --listactivemonitors || true
  echo
  echo "--- xrandr --verbose ---"
  xrandr --verbose || true
} > ${REMOTE_BASE}/xrandr.txt 2>&1

{
  echo "--- /sys/class/drm/*/status ---"
  for f in /sys/class/drm/*/status; do
    echo "## \$f"
    cat "\$f"
  done 2>/dev/null || true
  echo
  echo "--- /sys/class/drm/*/modes ---"
  for f in /sys/class/drm/*/modes; do
    echo "## \$f"
    cat "\$f"
  done 2>/dev/null || true
} > ${REMOTE_BASE}/drm_modes.txt

if command -v modetest >/dev/null 2>&1; then
  timeout 20s modetest -M amdgpu -c -p > ${REMOTE_BASE}/modetest.txt 2>&1 || timeout 20s modetest -c -p > ${REMOTE_BASE}/modetest.txt 2>&1 || true
fi

if command -v drm_info >/dev/null 2>&1; then
  timeout 20s drm_info > ${REMOTE_BASE}/drm_info.txt 2>&1 || true
fi

if command -v vulkaninfo >/dev/null 2>&1; then
  {
    echo "--- display timing related extensions ---"
    vulkaninfo 2>/dev/null | grep -E 'VK_GOOGLE_display_timing|VK_KHR_present_id|VK_KHR_present_wait' || true
  } > ${REMOTE_BASE}/vulkan_display_timing.txt 2>&1
fi

ls -lah ${REMOTE_BASE}
EOF
)

"${ROOT_DIR}/scripts/steamdeck-run.sh" "${REMOTE_SCRIPT}"
"${ROOT_DIR}/scripts/steamdeck-scp-from.sh" "${REMOTE_BASE}" "${ARTIFACT_ROOT}"

echo "Artifacts saved under ${ARTIFACT_DIR}"
