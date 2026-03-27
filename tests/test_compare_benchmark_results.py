import csv
import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
COMPARE_SCRIPT = REPO_ROOT / "scripts" / "compare-benchmark-results.py"
REPROJECT_QUALITY_ROWS = [
    {
        "label": "reproject-blend-default",
        "mode": "reproject-blend",
        "avgCpuTotalMs": 10.0,
        "avgCpuPerGeneratedFrameMs": 10.0,
    },
    {
        "label": "reproject-blend-no-gradient",
        "mode": "reproject-blend",
        "avgCpuTotalMs": 9.6,
        "avgCpuPerGeneratedFrameMs": 9.6,
    },
    {
        "label": "reproject-blend-no-chroma",
        "mode": "reproject-blend",
        "avgCpuTotalMs": 9.4,
        "avgCpuPerGeneratedFrameMs": 9.4,
    },
    {
        "label": "reproject-blend-no-ambiguity",
        "mode": "reproject-blend",
        "avgCpuTotalMs": 9.2,
        "avgCpuPerGeneratedFrameMs": 9.2,
    },
    {
        "label": "reproject-multi-count3-default",
        "mode": "reproject-multi-blend",
        "avgCpuTotalMs": 12.0,
        "avgCpuPerGeneratedFrameMs": 4.0,
    },
    {
        "label": "reproject-multi-count3-no-ambiguity",
        "mode": "reproject-multi-blend",
        "avgCpuTotalMs": 11.7,
        "avgCpuPerGeneratedFrameMs": 3.9,
    },
    {
        "label": "reproject-adaptive-multi-target180-default",
        "mode": "reproject-adaptive-multi-blend",
        "avgCpuTotalMs": 12.6,
        "avgCpuPerGeneratedFrameMs": 4.2,
    },
    {
        "label": "reproject-adaptive-multi-target180-no-ambiguity",
        "mode": "reproject-adaptive-multi-blend",
        "avgCpuTotalMs": 12.3,
        "avgCpuPerGeneratedFrameMs": 4.1,
    },
]


def write_results_csv(path: Path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "label",
                "mode",
                "avgCpuTotalMs",
                "avgCpuPerGeneratedFrameMs",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)


def run_compare(*args, cwd=REPO_ROOT):
    return subprocess.run(
        [sys.executable, str(COMPARE_SCRIPT), *args],
        cwd=cwd,
        text=True,
        capture_output=True,
        check=False,
    )


def test_reproject_quality_preset_accepts_improvements(tmp_path):
    baseline_dir = tmp_path / "baseline"
    candidate_dir = tmp_path / "candidate"
    write_results_csv(baseline_dir / "results.csv", REPROJECT_QUALITY_ROWS)

    improved_rows = []
    for row in REPROJECT_QUALITY_ROWS:
        improved = dict(row)
        improved["avgCpuTotalMs"] = round(float(row["avgCpuTotalMs"]) * 0.99, 4)
        improved["avgCpuPerGeneratedFrameMs"] = round(
            float(row["avgCpuPerGeneratedFrameMs"]) * 0.985, 4
        )
        improved_rows.append(improved)
    write_results_csv(candidate_dir / "results.csv", improved_rows)

    result = run_compare(
        "--preset",
        "reproject-quality",
        "--json",
        str(baseline_dir),
        str(candidate_dir),
    )

    assert result.returncode == 0, result.stderr
    payload = json.loads(result.stdout)
    assert payload["preset"] == "reproject-quality"
    assert payload["accepted"] is True
    assert payload["weightedImprovementPct"] > 0.25
    assert {item["label"] for item in payload["comparisons"]} == {
        row["label"] for row in REPROJECT_QUALITY_ROWS
    }


def test_reproject_quality_preset_rejects_large_default_case_regressions(tmp_path):
    baseline_dir = tmp_path / "baseline"
    candidate_dir = tmp_path / "candidate"
    write_results_csv(baseline_dir / "results.csv", REPROJECT_QUALITY_ROWS)

    regressed_rows = []
    for row in REPROJECT_QUALITY_ROWS:
        candidate = dict(row)
        if row["label"] == "reproject-multi-count3-default":
            candidate["avgCpuPerGeneratedFrameMs"] = round(
                float(row["avgCpuPerGeneratedFrameMs"]) * 1.01, 4
            )
        else:
            candidate["avgCpuTotalMs"] = round(float(row["avgCpuTotalMs"]) * 0.995, 4)
            candidate["avgCpuPerGeneratedFrameMs"] = round(
                float(row["avgCpuPerGeneratedFrameMs"]) * 0.995, 4
            )
        regressed_rows.append(candidate)
    write_results_csv(candidate_dir / "results.csv", regressed_rows)

    result = run_compare(
        "--preset",
        "reproject-quality",
        str(baseline_dir),
        str(candidate_dir),
    )

    assert result.returncode == 2
    assert "preset=reproject-quality" in result.stdout
    assert "accepted=0" in result.stdout
    assert "label=reproject-multi-count3-default" in result.stdout
