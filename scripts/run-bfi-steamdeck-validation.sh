#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
: "${OMFG_LAYER_IMPL:=rust}"

if [[ "${OMFG_LAYER_IMPL}" != "rust" ]]; then
  echo "BFI Steam Deck validation currently targets the Rust layer only." >&2
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
  local suffix="$1"
  local count="$2"
  local present_mode="$3"
  local bfi_period="$4"
  shift 4

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
  OMFG_LAYER_MODE=bfi \
  OMFG_VKCUBE_COUNT="${count}" \
  OMFG_VKCUBE_PRESENT_MODE="${present_mode}" \
  OMFG_VKCUBE_TIMEOUT_SEC=40 \
  OMFG_VKCUBE_ARTIFACT_SUFFIX="${suffix}" \
  OMFG_BFI_PERIOD="${bfi_period}" \
    "${ROOT_DIR}/scripts/test-steamdeck-vkcube.sh"

  local -a cmd=(
    python3 "${ROOT_DIR}/scripts/assert-vkcube-log.py"
    --mode bfi
    --log "${ROOT_DIR}/artifacts/steamdeck/rust/vkcube/bfi-${suffix}/omfg-vkcube.log"
  )
  if [[ ${skip_mode_markers} -eq 1 ]]; then
    cmd+=(--skip-mode-markers)
  fi
  if [[ ${#assert_args[@]} -gt 0 ]]; then
    cmd+=("${assert_args[@]}")
  fi
  "${cmd[@]}"
}

run_case smoke 120 "" 1 \
  "bfi settings; period=1" \
  "first generated black-frame present succeeded" \
  "black frame present=120"

run_case long 600 "" 1 \
  "bfi settings; period=1" \
  "vkQueuePresentKHR frame=600" \
  "black frame present=600"

run_case immediate 120 0 1 \
  "bfi settings; period=1" \
  "presentMode=IMMEDIATE" \
  "black frame present=120"

run_case period2-smoke 120 "" 2 \
  --skip-mode-markers \
  "bfi settings; period=2" \
  "first generated black-frame present succeeded" \
  "black frame present=60"

"${ROOT_DIR}/scripts/collect-steamdeck-display-info.sh" bfi-validation

echo "BFI Steam Deck validation passed for ${OMFG_LAYER_IMPL}"
