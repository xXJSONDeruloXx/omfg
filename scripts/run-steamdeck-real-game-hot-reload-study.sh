#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 4 ]]; then
  cat >&2 <<'EOF'
Usage:
  run-steamdeck-real-game-hot-reload-study.sh <preset>
  run-steamdeck-real-game-hot-reload-study.sh <appid> <slug> <title> [exe-regex]

Presets:
  re-village | resident-evil-village | 1196590
  stellar-blade | 3489700
  beyond | beyond-two-souls | 960990

Environment:
  OMFG_HOT_MODE=reproject-multi-blend
  OMFG_HOT_INITIAL_COUNT=0
  OMFG_HOT_RESERVED_COUNT=3
  OMFG_HOT_STEPS=20:1                 # comma-separated seconds:count steps
  OMFG_HOT_CONFIG_PATH=/home/deck/post-proc-fg-research/config/omfg-live.toml
  OMFG_GAME_WAIT_SEC=90
EOF
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOT_MODE="${OMFG_HOT_MODE:-reproject-multi-blend}"
HOT_INITIAL_COUNT="${OMFG_HOT_INITIAL_COUNT:-0}"
HOT_RESERVED_COUNT="${OMFG_HOT_RESERVED_COUNT:-3}"
HOT_STEPS="${OMFG_HOT_STEPS:-20:1}"
HOT_CONFIG_PATH="${OMFG_HOT_CONFIG_PATH:-/home/deck/post-proc-fg-research/config/omfg-live.toml}"
FALLBACK_REMOTE_LOG_PATH="${OMFG_FALLBACK_REMOTE_LOG_PATH:-/home/deck/post-proc-fg-research/logs/omfg-live-layer.log}"
RUN_ID="${OMFG_HOT_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
SUMMARY_ROOT="${ROOT_DIR}/artifacts/steamdeck/rust/real-games-hot/${RUN_ID}"
mkdir -p "${SUMMARY_ROOT}"

APP_ID=""
SLUG=""
TITLE=""
EXE_REGEX=""
DEFAULT_WAIT_SEC="90"

if [[ $# -eq 1 ]]; then
  case "$1" in
    re-village|resident-evil-village|1196590)
      APP_ID="1196590"
      SLUG="resident-evil-village"
      TITLE="Resident Evil Village"
      EXE_REGEX='re8.exe'
      DEFAULT_WAIT_SEC="90"
      ;;
    stellar-blade|3489700)
      APP_ID="3489700"
      SLUG="stellar-blade"
      TITLE="Stellar Blade™"
      EXE_REGEX='SB.exe|SB-Win64-Shipping.exe'
      DEFAULT_WAIT_SEC="90"
      ;;
    beyond|beyond-two-souls|960990)
      APP_ID="960990"
      SLUG="beyond-two-souls"
      TITLE="Beyond: Two Souls"
      EXE_REGEX='BeyondTwoSouls_Steam.exe'
      DEFAULT_WAIT_SEC="60"
      ;;
    *)
      echo "Unknown preset: $1" >&2
      exit 1
      ;;
  esac
else
  APP_ID="$1"
  SLUG="$2"
  TITLE="$3"
  EXE_REGEX="${4:-}"
fi

: "${OMFG_GAME_WAIT_SEC:=${DEFAULT_WAIT_SEC}}"

build_hot_config_contents() {
  local count="$1"
  cat <<EOF
OMFG_LAYER_MODE = "${HOT_MODE}"
OMFG_MULTI_BLEND_COUNT = ${count}
OMFG_MULTI_BLEND_RESERVED_COUNT = ${HOT_RESERVED_COUNT}
OMFG_REPROJECT_SEARCH_RADIUS = ${OMFG_REPROJECT_SEARCH_RADIUS:-2}
OMFG_REPROJECT_PATCH_RADIUS = ${OMFG_REPROJECT_PATCH_RADIUS:-1}
OMFG_REPROJECT_CONFIDENCE_SCALE = ${OMFG_REPROJECT_CONFIDENCE_SCALE:-4.0}
EOF

  for key in \
    OMFG_PRESENT_TIMING \
    OMFG_PRESENT_WAIT \
    OMFG_PRESENT_WAIT_TIMEOUT_NS \
    OMFG_VISUAL_HOLD_MS \
    OMFG_BENCHMARK \
    OMFG_BENCHMARK_LABEL \
    OMFG_BLEND_ORIGINAL_PRESENT_FIRST \
    OMFG_GENERATED_ACQUIRE_TIMEOUT_NS \
    OMFG_GENERATED_ACQUIRE_TIMEOUT_INTERVAL_MULTIPLIER \
    OMFG_GENERATED_ACQUIRE_TIMEOUT_MIN_NS \
    OMFG_GENERATED_ACQUIRE_TIMEOUT_MAX_NS
  do
    value="${!key:-}"
    if [[ -n "${value}" ]]; then
      printf '%s = %s\n' "${key}" "${value}"
    fi
  done
}

write_hot_config() {
  local count="$1"
  local tmp
  tmp="$(mktemp)"
  build_hot_config_contents "${count}" > "${tmp}"
  "${ROOT_DIR}/scripts/steamdeck-scp-to.sh" "${tmp}" "${HOT_CONFIG_PATH}" >/dev/null
  rm -f "${tmp}"
}

"${ROOT_DIR}/scripts/steamdeck-run.sh" "rm -f ${FALLBACK_REMOTE_LOG_PATH}"
write_hot_config "${HOT_INITIAL_COUNT}"

step_log="${SUMMARY_ROOT}/${SLUG}-hot-steps.txt"
: > "${step_log}"
(
  IFS=',' read -r -a steps <<< "${HOT_STEPS}"
  for step in "${steps[@]}"; do
    delay="${step%%:*}"
    count="${step##*:}"
    sleep "${delay}"
    printf '[%s] applying hot step count=%s after=%ss\n' "$(date +%s)" "${count}" "${delay}" | tee -a "${step_log}"
    write_hot_config "${count}" >> "${step_log}" 2>&1
  done
) &
scheduler_pid=$!
trap 'kill ${scheduler_pid} >/dev/null 2>&1 || true' EXIT

OMFG_LAYER_MODE="${HOT_MODE}" \
OMFG_HOT_CONFIG_PATH="${HOT_CONFIG_PATH}" \
OMFG_GAME_WAIT_SEC="${OMFG_GAME_WAIT_SEC}" \
"${ROOT_DIR}/scripts/test-steamdeck-steam-game.sh" "${APP_ID}" "${SLUG}" "${TITLE}" "${EXE_REGEX}"

wait "${scheduler_pid}" || true
trap - EXIT

ARTIFACT_DIR="${ROOT_DIR}/artifacts/steamdeck/rust/real-games/${SLUG}/${HOT_MODE}"
cp -f "${step_log}" "${ARTIFACT_DIR}/hot-steps-${RUN_ID}.txt"

fallback_local_log="${ARTIFACT_DIR}/hot-live-log-${RUN_ID}.log"
if "${ROOT_DIR}/scripts/steamdeck-scp-from.sh" "${FALLBACK_REMOTE_LOG_PATH}" "${fallback_local_log}"; then
  summary_input="${fallback_local_log}"
else
  summary_input="${ARTIFACT_DIR}/omfg.log"
fi

python3 "${ROOT_DIR}/scripts/summarize-real-game-log.py" "${summary_input}" | tee "${ARTIFACT_DIR}/hot-summary-${RUN_ID}.txt"
python3 "${ROOT_DIR}/scripts/summarize-real-game-log.py" --json "${summary_input}" > "${ARTIFACT_DIR}/hot-summary-${RUN_ID}.json"
if grep -q 'benchmark summary;' "${summary_input}" 2>/dev/null; then
  python3 "${ROOT_DIR}/scripts/summarize-benchmark-log.py" "${summary_input}" | tee "${ARTIFACT_DIR}/hot-benchmark-${RUN_ID}.txt"
  python3 "${ROOT_DIR}/scripts/summarize-benchmark-log.py" --json "${summary_input}" > "${ARTIFACT_DIR}/hot-benchmark-${RUN_ID}.json"
fi

echo "Hot-reload study artifacts saved under ${ARTIFACT_DIR} (summary_input=${summary_input})"
