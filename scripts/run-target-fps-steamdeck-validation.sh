#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
: "${OMFG_LAYER_IMPL:=rust}"

ENV_FILE="${ROOT_DIR}/.env.steamdeck.local"
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  set +a
fi

if [[ "${OMFG_LAYER_IMPL}" != "rust" ]]; then
  echo "Target-FPS Steam Deck validation currently targets the Rust layer only." >&2
  exit 1
fi

if [[ -z "${STEAMDECK_PASS:-}" ]]; then
  echo "STEAMDECK_PASS not set; cannot run Steam Deck validation." >&2
  exit 1
fi

"${ROOT_DIR}/scripts/test-rust-layer.sh"
OMFG_LAYER_IMPL="${OMFG_LAYER_IMPL}" "${ROOT_DIR}/scripts/build-linux-amd64.sh"
OMFG_LAYER_IMPL="${OMFG_LAYER_IMPL}" "${ROOT_DIR}/scripts/deploy-steamdeck-layer.sh"

run_case() {
  local mode="$1"
  local suffix="$2"
  local count="$3"
  local present_mode="$4"
  local target_fps="$5"
  local min_generated="$6"
  local max_generated="$7"
  shift 7

  local skip_mode_markers=0
  if [[ "${1:-}" == "--skip-mode-markers" ]]; then
    skip_mode_markers=1
    shift
  fi

  local -a assert_args=()
  while [[ $# -gt 0 ]]; do
    assert_args+=(--expect-text "$1")
    shift
  done

  OMFG_LAYER_IMPL="${OMFG_LAYER_IMPL}" \
  OMFG_LAYER_MODE="${mode}" \
  OMFG_VKCUBE_COUNT="${count}" \
  OMFG_VKCUBE_PRESENT_MODE="${present_mode}" \
  OMFG_VKCUBE_TIMEOUT_SEC=40 \
  OMFG_VKCUBE_ARTIFACT_SUFFIX="${suffix}" \
  OMFG_ADAPTIVE_MULTI_TARGET_FPS="${target_fps}" \
  OMFG_ADAPTIVE_MULTI_MIN_GENERATED_FRAMES="${min_generated}" \
  OMFG_ADAPTIVE_MULTI_MAX_GENERATED_FRAMES="${max_generated}" \
  OMFG_ADAPTIVE_MULTI_INTERVAL_SMOOTHING_ALPHA=0.25 \
    "${ROOT_DIR}/scripts/test-steamdeck-vkcube.sh"

  local -a cmd=(
    python3 "${ROOT_DIR}/scripts/assert-vkcube-log.py"
    --mode "${mode}"
    --log "${ROOT_DIR}/artifacts/steamdeck/rust/vkcube/${mode}-${suffix}/omfg-vkcube.log"
  )
  if [[ ${skip_mode_markers} -eq 1 ]]; then
    cmd+=(--skip-mode-markers)
  fi
  if [[ ${#assert_args[@]} -gt 0 ]]; then
    cmd+=("${assert_args[@]}")
  fi
  "${cmd[@]}"
}

run_case adaptive-multi-blend target100-long 600 "" 100 0 2 \
  "targetFps=100.0" \
  "emittedGeneratedFrames=0" \
  "emittedGeneratedFrames=1" \
  "vkQueuePresentKHR frame=600"

run_case adaptive-multi-blend target120-smoke 120 "" 120 0 2 \
  "targetFps=120.0" \
  "emittedGeneratedFrames=1"

run_case adaptive-multi-blend target150-smoke 120 "" 150 0 2 \
  "targetFps=150.0" \
  "emittedGeneratedFrames=1" \
  "emittedGeneratedFrames=2"

run_case adaptive-multi-blend target90-immediate 120 0 90 0 2 \
  --skip-mode-markers \
  "targetFps=90.0" \
  "presentMode=IMMEDIATE" \
  "emittedGeneratedFrames=0"

run_case reproject-adaptive-multi-blend target120-smoke 120 "" 120 0 2 \
  "targetFps=120.0" \
  "emittedGeneratedFrames=1"

run_case reproject-adaptive-multi-blend target180-smoke 120 "" 180 0 2 \
  "targetFps=180.0" \
  "emittedGeneratedFrames=1" \
  "emittedGeneratedFrames=2"

echo "Target-FPS Steam Deck validation passed for ${OMFG_LAYER_IMPL}"
