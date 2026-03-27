#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
: "${PPFG_LAYER_IMPL:=rust}"
MIN_COUNT="${PPFG_MULTI_SWEEP_MIN_COUNT:-1}"
MAX_COUNT="${PPFG_MULTI_SWEEP_MAX_COUNT:-20}"
VKCUBE_COUNT="${PPFG_MULTI_SWEEP_VKCUBE_COUNT:-30}"
TIMEOUT_SEC="${PPFG_MULTI_SWEEP_TIMEOUT_SEC:-25}"
RUN_ID="${PPFG_MULTI_SWEEP_RUN_ID:-multi-count-sweep-$(date +%Y%m%d-%H%M%S)}"
RESULTS_DIR="${ROOT_DIR}/artifacts/steamdeck/${PPFG_LAYER_IMPL}/benchmark/${RUN_ID}"
RESULTS_CSV="${RESULTS_DIR}/results.csv"
SUMMARY_TXT="${RESULTS_DIR}/summary.txt"

mkdir -p "${RESULTS_DIR}"
printf 'count,summaryPresent,firstSuccess,samples,generatedFrames,expectedGeneratedFrames,successRatio,avgCpuAcquireMs,avgCpuSubmitWaitMs,avgCpuTotalMs,avgCpuPerGeneratedFrameMs,avgGpuCmdMs,avgGpuPerGeneratedFrameMs,timeoutWarnings,fallbackWarnings,duplicateWarnings\n' > "${RESULTS_CSV}"
: > "${SUMMARY_TXT}"

for count in $(seq "${MIN_COUNT}" "${MAX_COUNT}"); do
  (
    export PPFG_LAYER_IMPL="${PPFG_LAYER_IMPL}"
    export PPFG_LAYER_MODE=multi-blend
    export PPFG_MULTI_BLEND_COUNT="${count}"
    export PPFG_BENCHMARK=1
    export PPFG_BENCHMARK_LABEL="multi-blend-count${count}-${RUN_ID}"
    export PPFG_VKCUBE_COUNT="${VKCUBE_COUNT}"
    export PPFG_VKCUBE_TIMEOUT_SEC="${TIMEOUT_SEC}"
    export PPFG_VKCUBE_ARTIFACT_SUFFIX="${RUN_ID}-count${count}"
    "${ROOT_DIR}/scripts/test-steamdeck-vkcube.sh"
  ) > "/tmp/${RUN_ID}-count${count}.stdout"

  LOG_PATH="${ROOT_DIR}/artifacts/steamdeck/${PPFG_LAYER_IMPL}/vkcube/multi-blend-${RUN_ID}-count${count}/ppfg-vkcube.log"
  python3 - <<'PY' "${count}" "${LOG_PATH}" "${RESULTS_CSV}" "${SUMMARY_TXT}"
import sys
from pathlib import Path

count = int(sys.argv[1])
log_path = Path(sys.argv[2])
results_csv = Path(sys.argv[3])
summary_txt = Path(sys.argv[4])
text = log_path.read_text().splitlines()
summary_line = None
for line in text:
    if 'benchmark summary;' in line:
        summary_line = line.split('benchmark summary;', 1)[1].strip()

parts = {}
if summary_line is not None:
    for part in summary_line.split(';'):
        part = part.strip()
        if '=' in part:
            k, v = part.split('=', 1)
            parts[k.strip()] = v.strip()

timeout_warnings = sum('AcquireNextImageKHR timed out for multi-blend frame' in line for line in text)
fallback_warnings = sum('multi-blend falling back to cpu acquire path' in line for line in text)
duplicate_warnings = sum('duplicate or current source image index' in line for line in text)
first_success = any('first multi blended generated-frame present succeeded' in line for line in text)
summary_present = summary_line is not None
samples = int(parts['samples']) if summary_present else 0
generated_frames = int(parts['generatedFrames']) if summary_present else 0
expected_generated_frames = samples * count if summary_present else 0
success_ratio = (generated_frames / expected_generated_frames) if expected_generated_frames else 0.0
row = {
    'count': count,
    'summaryPresent': int(summary_present),
    'firstSuccess': int(first_success),
    'samples': samples,
    'generatedFrames': generated_frames,
    'expectedGeneratedFrames': expected_generated_frames,
    'successRatio': f"{success_ratio:.3f}",
    'avgCpuAcquireMs': parts.get('avgCpuAcquireMs', ''),
    'avgCpuSubmitWaitMs': parts.get('avgCpuSubmitWaitMs', ''),
    'avgCpuTotalMs': parts.get('avgCpuTotalMs', ''),
    'avgCpuPerGeneratedFrameMs': parts.get('avgCpuPerGeneratedFrameMs', ''),
    'avgGpuCmdMs': parts.get('avgGpuCmdMs', ''),
    'avgGpuPerGeneratedFrameMs': parts.get('avgGpuPerGeneratedFrameMs', ''),
    'timeoutWarnings': timeout_warnings,
    'fallbackWarnings': fallback_warnings,
    'duplicateWarnings': duplicate_warnings,
}
with results_csv.open('a') as f:
    f.write(','.join(str(row[k]) for k in [
        'count','summaryPresent','firstSuccess','samples','generatedFrames','expectedGeneratedFrames','successRatio',
        'avgCpuAcquireMs','avgCpuSubmitWaitMs','avgCpuTotalMs','avgCpuPerGeneratedFrameMs','avgGpuCmdMs','avgGpuPerGeneratedFrameMs',
        'timeoutWarnings','fallbackWarnings','duplicateWarnings']) + '\n')
with summary_txt.open('a') as f:
    if summary_present:
        f.write(
            f"count={count} OK samples={samples} gen={generated_frames}/{expected_generated_frames} ratio={success_ratio:.3f} "
            f"cpuTotal={parts.get('avgCpuTotalMs')} cpuPerGen={parts.get('avgCpuPerGeneratedFrameMs')} "
            f"gpuPerGen={parts.get('avgGpuPerGeneratedFrameMs')} timeouts={timeout_warnings} fallbacks={fallback_warnings}\n"
        )
    else:
        f.write(
            f"count={count} FAIL firstSuccess={int(first_success)} timeouts={timeout_warnings} fallbacks={fallback_warnings} duplicates={duplicate_warnings}\n"
        )
PY
  echo "completed count ${count}"
done

echo "results saved under ${RESULTS_DIR}"
cat "${SUMMARY_TXT}"
