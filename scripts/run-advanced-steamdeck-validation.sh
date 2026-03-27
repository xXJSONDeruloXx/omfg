#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
: "${OMFG_LAYER_IMPL:=rust}"

if [[ "${OMFG_LAYER_IMPL}" != "rust" ]]; then
  echo "Advanced Steam Deck validation currently targets the Rust layer only." >&2
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
  shift 4

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
    "${ROOT_DIR}/scripts/test-steamdeck-vkcube.sh"

  local -a cmd=(
    python3 "${ROOT_DIR}/scripts/assert-vkcube-log.py"
    --mode "${mode}"
    --log "${ROOT_DIR}/artifacts/steamdeck/rust/vkcube/${mode}-${suffix}/omfg-vkcube.log"
  )
  if [[ ${#assert_args[@]} -gt 0 ]]; then
    cmd+=("${assert_args[@]}")
  fi
  "${cmd[@]}"
}

run_case search-adaptive-blend long 600 "" "vkQueuePresentKHR frame=600"
run_case search-adaptive-blend immediate 120 0 "presentMode=IMMEDIATE"
run_case reproject-blend smoke 120 ""
run_case reproject-blend long 600 "" "vkQueuePresentKHR frame=600"
run_case reproject-blend immediate 120 0 "presentMode=IMMEDIATE"
run_case reproject-adaptive-blend smoke 120 ""
run_case reproject-adaptive-blend long 600 "" "vkQueuePresentKHR frame=600"
run_case reproject-adaptive-blend immediate 120 0 "presentMode=IMMEDIATE"
run_case reproject-multi-blend smoke 120 ""
run_case reproject-multi-blend long 600 "" "vkQueuePresentKHR frame=600"
run_case reproject-multi-blend immediate 120 0 "presentMode=IMMEDIATE"
run_case reproject-adaptive-multi-blend smoke 120 ""
run_case reproject-adaptive-multi-blend long 600 "" "vkQueuePresentKHR frame=600"
run_case reproject-adaptive-multi-blend immediate 120 0 "presentMode=IMMEDIATE"

echo "Advanced Steam Deck validation passed for ${OMFG_LAYER_IMPL}"
