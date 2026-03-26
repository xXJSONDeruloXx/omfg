#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
: "${PPFG_LAYER_IMPL:=rust}"

if [[ "${PPFG_LAYER_IMPL}" != "rust" ]]; then
  echo "Target-FPS Steam Deck validation currently targets the Rust layer only." >&2
  exit 1
fi

if [[ -z "${STEAMDECK_PASS:-}" ]]; then
  echo "STEAMDECK_PASS not set; cannot run Steam Deck validation." >&2
  exit 1
fi

"${ROOT_DIR}/scripts/test-rust-layer.sh"
PPFG_LAYER_IMPL="${PPFG_LAYER_IMPL}" "${ROOT_DIR}/scripts/build-linux-amd64.sh"
PPFG_LAYER_IMPL="${PPFG_LAYER_IMPL}" "${ROOT_DIR}/scripts/deploy-steamdeck-layer.sh"

run_case() {
  local suffix="$1"
  local count="$2"
  local present_mode="$3"
  local target_fps="$4"
  local min_generated="$5"
  local max_generated="$6"
  shift 6

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

  PPFG_LAYER_IMPL="${PPFG_LAYER_IMPL}" \
  PPFG_LAYER_MODE=adaptive-multi-blend \
  PPFG_VKCUBE_COUNT="${count}" \
  PPFG_VKCUBE_PRESENT_MODE="${present_mode}" \
  PPFG_VKCUBE_TIMEOUT_SEC=40 \
  PPFG_VKCUBE_ARTIFACT_SUFFIX="${suffix}" \
  PPFG_ADAPTIVE_MULTI_TARGET_FPS="${target_fps}" \
  PPFG_ADAPTIVE_MULTI_MIN_GENERATED_FRAMES="${min_generated}" \
  PPFG_ADAPTIVE_MULTI_MAX_GENERATED_FRAMES="${max_generated}" \
  PPFG_ADAPTIVE_MULTI_INTERVAL_SMOOTHING_ALPHA=0.25 \
    "${ROOT_DIR}/scripts/test-steamdeck-vkcube.sh"

  local -a cmd=(
    python3 "${ROOT_DIR}/scripts/assert-vkcube-log.py"
    --mode adaptive-multi-blend
    --log "${ROOT_DIR}/artifacts/steamdeck/rust/vkcube/adaptive-multi-blend-${suffix}/ppfg-vkcube.log"
  )
  if [[ ${skip_mode_markers} -eq 1 ]]; then
    cmd+=(--skip-mode-markers)
  fi
  if [[ ${#assert_args[@]} -gt 0 ]]; then
    cmd+=("${assert_args[@]}")
  fi
  "${cmd[@]}"
}

run_case target100-long 600 "" 100 0 2 \
  "targetFps=100.0" \
  "emittedGeneratedFrames=0" \
  "emittedGeneratedFrames=1" \
  "vkQueuePresentKHR frame=600"

run_case target120-smoke 120 "" 120 0 2 \
  "targetFps=120.0" \
  "emittedGeneratedFrames=1"

run_case target150-smoke 120 "" 150 0 2 \
  "targetFps=150.0" \
  "emittedGeneratedFrames=1" \
  "emittedGeneratedFrames=2"

run_case target90-immediate 120 0 90 0 2 \
  --skip-mode-markers \
  "targetFps=90.0" \
  "presentMode=IMMEDIATE" \
  "emittedGeneratedFrames=0"

echo "Target-FPS Steam Deck validation passed for ${PPFG_LAYER_IMPL}"
