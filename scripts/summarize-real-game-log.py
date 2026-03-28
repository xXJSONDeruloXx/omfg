#!/usr/bin/env python3
import argparse
import json
import re
from pathlib import Path

ORDER = [
    "path",
    "deviceOk",
    "swapchainCount",
    "presentMode",
    "swapchainImages",
    "swapchainMinBefore",
    "swapchainMinAfter",
    "hotReloads",
    "passthroughLastFrame",
    "generatedMode",
    "generatedLastPresent",
    "generatedEventCount",
    "firstGeneratedSucceeded",
    "presentWaitResultCount",
    "presentWaitNonZeroCount",
    "presentTimingSampleCount",
    "presentTimingAvgActualMs",
    "presentTimingAvgMarginMs",
    "benchmarkSampleCount",
    "benchmarkAvgCpuTotalMs",
    "benchmarkAvgCpuSubmitWaitMs",
    "benchmarkAvgCpuGeneratedPresentMs",
    "benchmarkAvgCpuOriginalPresentMs",
    "benchmarkAvgGpuCmdMs",
    "appSuppliedPresentIdSkips",
    "acquireTimeouts",
    "warnings",
]

SWAPCHAIN_RE = re.compile(
    r"vkCreateSwapchainKHR ok; .*presentMode=(?P<present_mode>[^;]+); minImages=(?P<before>\d+)->(?P<after>\d+); .*images=(?P<images>\d+)"
)
PASSTHROUGH_RE = re.compile(r"vkQueuePresentKHR passthrough frame=(?P<frame>\d+)")
GENERATED_RE = re.compile(r"(?P<label>[A-Za-z0-9\- ]+) frame present=(?P<present>\d+)")
PRESENT_WAIT_RE = re.compile(r"present wait result; .*result=(?P<result>-?\d+)")
PRESENT_TIMING_RE = re.compile(
    r"present timing sample; .*actualMs=(?P<actual>[-0-9.]+); .*marginMs=(?P<margin>[-0-9.]+)"
)
BENCHMARK_SAMPLE_RE = re.compile(
    r"benchmark sample; .*cpuSubmitWaitMs=(?P<cpu_submit_wait>[-0-9.]+); "
    r"cpuGeneratedPresentMs=(?P<cpu_generated_present>[-0-9.]+); "
    r"cpuOriginalPresentMs=(?P<cpu_original_present>[-0-9.]+); .*"
    r"cpuTotalMs=(?P<cpu_total>[-0-9.]+); gpuCmdMs=(?P<gpu_cmd>[-0-9.]+)"
)


def parse_log(path: Path) -> dict:
    data = {
        "path": str(path),
        "deviceOk": 0,
        "swapchainCount": 0,
        "presentMode": "",
        "swapchainImages": "",
        "swapchainMinBefore": "",
        "swapchainMinAfter": "",
        "hotReloads": 0,
        "passthroughLastFrame": 0,
        "generatedMode": "",
        "generatedLastPresent": 0,
        "generatedEventCount": 0,
        "firstGeneratedSucceeded": 0,
        "presentWaitResultCount": 0,
        "presentWaitNonZeroCount": 0,
        "presentTimingSampleCount": 0,
        "presentTimingAvgActualMs": "",
        "presentTimingAvgMarginMs": "",
        "benchmarkSampleCount": 0,
        "benchmarkAvgCpuTotalMs": "",
        "benchmarkAvgCpuSubmitWaitMs": "",
        "benchmarkAvgCpuGeneratedPresentMs": "",
        "benchmarkAvgCpuOriginalPresentMs": "",
        "benchmarkAvgGpuCmdMs": "",
        "appSuppliedPresentIdSkips": 0,
        "acquireTimeouts": 0,
        "warnings": 0,
    }
    timing_actual = []
    timing_margin = []
    benchmark_cpu_total = []
    benchmark_cpu_submit_wait = []
    benchmark_cpu_generated_present = []
    benchmark_cpu_original_present = []
    benchmark_gpu_cmd = []

    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "vkCreateDevice ok;" in line:
            data["deviceOk"] = 1
        if "hot config reloaded:" in line:
            data["hotReloads"] += 1
        if "first " in line and "present succeeded" in line:
            data["firstGeneratedSucceeded"] = 1
        if "skipping OMFG present-id injection;" in line:
            data["appSuppliedPresentIdSkips"] += 1
        if "AcquireNextImageKHR timed out" in line:
            data["acquireTimeouts"] += 1
        if "[omfg][warn]" in line:
            data["warnings"] += 1

        match = SWAPCHAIN_RE.search(line)
        if match:
            data["swapchainCount"] += 1
            data["presentMode"] = match.group("present_mode")
            data["swapchainImages"] = int(match.group("images"))
            data["swapchainMinBefore"] = int(match.group("before"))
            data["swapchainMinAfter"] = int(match.group("after"))

        match = PASSTHROUGH_RE.search(line)
        if match:
            data["passthroughLastFrame"] = max(
                data["passthroughLastFrame"], int(match.group("frame"))
            )

        match = GENERATED_RE.search(line)
        if match:
            data["generatedMode"] = match.group("label").strip()
            data["generatedLastPresent"] = max(
                data["generatedLastPresent"], int(match.group("present"))
            )
            data["generatedEventCount"] += 1

        match = PRESENT_WAIT_RE.search(line)
        if match:
            result = int(match.group("result"))
            data["presentWaitResultCount"] += 1
            if result != 0:
                data["presentWaitNonZeroCount"] += 1

        match = PRESENT_TIMING_RE.search(line)
        if match:
            data["presentTimingSampleCount"] += 1
            timing_actual.append(float(match.group("actual")))
            timing_margin.append(float(match.group("margin")))

        match = BENCHMARK_SAMPLE_RE.search(line)
        if match:
            data["benchmarkSampleCount"] += 1
            benchmark_cpu_total.append(float(match.group("cpu_total")))
            benchmark_cpu_submit_wait.append(float(match.group("cpu_submit_wait")))
            benchmark_cpu_generated_present.append(float(match.group("cpu_generated_present")))
            benchmark_cpu_original_present.append(float(match.group("cpu_original_present")))
            benchmark_gpu_cmd.append(float(match.group("gpu_cmd")))

    if timing_actual:
        data["presentTimingAvgActualMs"] = round(sum(timing_actual) / len(timing_actual), 3)
        data["presentTimingAvgMarginMs"] = round(sum(timing_margin) / len(timing_margin), 3)
    if benchmark_cpu_total:
        data["benchmarkAvgCpuTotalMs"] = round(sum(benchmark_cpu_total) / len(benchmark_cpu_total), 3)
        data["benchmarkAvgCpuSubmitWaitMs"] = round(sum(benchmark_cpu_submit_wait) / len(benchmark_cpu_submit_wait), 3)
        data["benchmarkAvgCpuGeneratedPresentMs"] = round(sum(benchmark_cpu_generated_present) / len(benchmark_cpu_generated_present), 3)
        data["benchmarkAvgCpuOriginalPresentMs"] = round(sum(benchmark_cpu_original_present) / len(benchmark_cpu_original_present), 3)
        data["benchmarkAvgGpuCmdMs"] = round(sum(benchmark_gpu_cmd) / len(benchmark_gpu_cmd), 3)

    return data


def csv_escape(value):
    text = str(value)
    if any(ch in text for ch in [",", '"', "\n"]):
        text = '"' + text.replace('"', '""') + '"'
    return text


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("log_path", type=Path, nargs="?")
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument("--csv", action="store_true")
    parser.add_argument("--header", action="store_true")
    args = parser.parse_args()

    if args.header:
        print(",".join(ORDER))
        return

    if args.log_path is None:
        parser.error("log_path is required unless --header is used")

    data = parse_log(args.log_path)

    if args.as_json:
        print(json.dumps(data, indent=2, sort_keys=True))
        return

    if args.csv:
        print(",".join(csv_escape(data.get(key, "")) for key in ORDER))
        return

    print(
        "path={path} deviceOk={deviceOk} swapchainCount={swapchainCount} presentMode={presentMode} "
        "images={swapchainImages} minImages={swapchainMinBefore}->{swapchainMinAfter} hotReloads={hotReloads} "
        "passthroughLastFrame={passthroughLastFrame} generatedMode={generatedMode} generatedLastPresent={generatedLastPresent} "
        "generatedEventCount={generatedEventCount} firstGeneratedSucceeded={firstGeneratedSucceeded} "
        "presentWaitResultCount={presentWaitResultCount} presentWaitNonZeroCount={presentWaitNonZeroCount} "
        "presentTimingSampleCount={presentTimingSampleCount} benchmarkSampleCount={benchmarkSampleCount} "
        "benchmarkAvgCpuTotalMs={benchmarkAvgCpuTotalMs} benchmarkAvgCpuSubmitWaitMs={benchmarkAvgCpuSubmitWaitMs} "
        "benchmarkAvgCpuGeneratedPresentMs={benchmarkAvgCpuGeneratedPresentMs} benchmarkAvgCpuOriginalPresentMs={benchmarkAvgCpuOriginalPresentMs} "
        "benchmarkAvgGpuCmdMs={benchmarkAvgGpuCmdMs} appSuppliedPresentIdSkips={appSuppliedPresentIdSkips} "
        "acquireTimeouts={acquireTimeouts} warnings={warnings}".format(**data)
    )


if __name__ == "__main__":
    main()
