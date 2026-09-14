#!/usr/bin/env python3
"""Summarize P1-05 contention samples as distributions, outliers and UTC patterns."""

from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


METRICS = {
    "seq_write_mib_s": ("MiB/s", "higher"),
    "small_create_files_s": ("files/s", "higher"),
    "small_stat_files_s": ("files/s", "higher"),
    "small_delete_files_s": ("files/s", "higher"),
    "sha256_mib_s": ("MiB/s", "higher"),
    "zstd_mib_s": ("MiB/s", "higher"),
    "docker_info_ms": ("ms", "lower"),
    "https_total_ms": ("ms", "lower"),
}

SUCCESS_GATES = {
    "seq_write_mib_s": "seq_write_rc",
    "small_create_files_s": "small_create_rc",
    "small_stat_files_s": "small_stat_rc",
    "small_delete_files_s": "small_delete_rc",
    "sha256_mib_s": "sha256_rc",
    "zstd_mib_s": "zstd_rc",
    "docker_info_ms": "docker_info_rc",
    "https_total_ms": "https_curl_rc",
}


def percentile(values: list[float], p: float) -> float:
    if not values:
        raise ValueError("empty values")
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    index = (len(ordered) - 1) * p
    lo = math.floor(index)
    hi = math.ceil(index)
    if lo == hi:
        return ordered[lo]
    frac = index - lo
    return ordered[lo] * (1.0 - frac) + ordered[hi] * frac


def num(value: str | None) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except ValueError:
        return None


def successful(row: dict[str, str], metric: str) -> bool:
    gate = SUCCESS_GATES.get(metric)
    if not gate:
        return True
    if metric == "https_total_ms" and row.get("https_route_found") != "yes":
        return False
    return row.get(gate) == "0"


def round_or_none(value: float | None, digits: int = 4) -> float | None:
    return None if value is None else round(value, digits)


def summarize_metric(rows: list[dict[str, str]], metric: str) -> dict[str, Any]:
    unit, preferred = METRICS[metric]
    observations: list[tuple[float, str]] = []
    for row in rows:
        value = num(row.get(metric))
        if value is not None and successful(row, metric):
            observations.append((value, row["timestamp_utc"]))

    values = [v for v, _ in observations]
    result: dict[str, Any] = {
        "unit": unit,
        "preferred_direction": preferred,
        "successful_samples": len(values),
        "failed_or_missing_samples": len(rows) - len(values),
    }
    if not values:
        return result

    mean = statistics.fmean(values)
    stdev = statistics.pstdev(values) if len(values) > 1 else 0.0
    worst_sorted = sorted(observations, key=lambda item: item[0], reverse=(preferred == "lower"))[:5]

    result.update(
        {
            "min": round(min(values), 4),
            "p10": round(percentile(values, 0.10), 4),
            "median": round(statistics.median(values), 4),
            "p90": round(percentile(values, 0.90), 4),
            "p95": round(percentile(values, 0.95), 4),
            "max": round(max(values), 4),
            "mean": round(mean, 4),
            "stdev": round(stdev, 4),
            "coefficient_of_variation": round(stdev / mean, 4) if mean else None,
            "worst_observations": [
                {"timestamp_utc": ts, "value": round(value, 4)} for value, ts in worst_sorted
            ],
        }
    )

    by_hour: dict[int, list[float]] = defaultdict(list)
    for value, ts in observations:
        hour = datetime.fromisoformat(ts.replace("Z", "+00:00")).hour
        by_hour[hour].append(value)
    result["utc_hour_medians"] = {
        f"{hour:02d}": {"count": len(vals), "median": round(statistics.median(vals), 4)}
        for hour, vals in sorted(by_hour.items())
    }
    return result


def build_summary(path: Path, expected_interval_minutes: int) -> dict[str, Any]:
    with path.open(newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    if not rows:
        raise SystemExit("sample CSV contains no data rows")

    rows.sort(key=lambda row: int(row["epoch"]))
    epochs = [int(row["epoch"]) for row in rows]
    duration_hours = (epochs[-1] - epochs[0]) / 3600.0 if len(epochs) > 1 else 0.0
    gaps_minutes = [
        (b - a) / 60.0 for a, b in zip(epochs, epochs[1:])
    ]
    expected_samples = math.floor((epochs[-1] - epochs[0]) / (expected_interval_minutes * 60)) + 1

    quota_used = [num(row.get("quota_used_kib")) for row in rows]
    quota_used = [v for v in quota_used if v is not None]
    df_available = [num(row.get("df_available_kib")) for row in rows]
    df_available = [v for v in df_available if v is not None]

    result: dict[str, Any] = {
        "task": "P1-05",
        "sample_count": len(rows),
        "first_sample_utc": rows[0]["timestamp_utc"],
        "last_sample_utc": rows[-1]["timestamp_utc"],
        "observed_duration_hours": round(duration_hours, 4),
        "minimum_24h_met": duration_hours >= 24.0,
        "expected_interval_minutes": expected_interval_minutes,
        "expected_samples_over_observed_span": expected_samples,
        "coverage_ratio": round(len(rows) / expected_samples, 4) if expected_samples else None,
        "max_gap_minutes": round(max(gaps_minutes), 4) if gaps_minutes else None,
        "median_gap_minutes": round(statistics.median(gaps_minutes), 4) if gaps_minutes else None,
        "https_route_available_samples": sum(row.get("https_route_found") == "yes" for row in rows),
        "metrics": {metric: summarize_metric(rows, metric) for metric in METRICS},
        "space": {
            "quota_used_kib_min": round_or_none(min(quota_used) if quota_used else None, 0),
            "quota_used_kib_max": round_or_none(max(quota_used) if quota_used else None, 0),
            "df_available_kib_min": round_or_none(min(df_available) if df_available else None, 0),
            "df_available_kib_max": round_or_none(max(df_available) if df_available else None, 0),
        },
    }

    total_sample_ms = [num(row.get("total_sample_ms")) for row in rows]
    total_sample_ms = [v for v in total_sample_ms if v is not None]
    result["sampler_runtime"] = {
        "median_ms": round(statistics.median(total_sample_ms), 4) if total_sample_ms else None,
        "max_ms": round(max(total_sample_ms), 4) if total_sample_ms else None,
        "duty_cycle_fraction_estimate": (
            round((sum(total_sample_ms) / 1000.0) / max(1, epochs[-1] - epochs[0]), 8)
            if len(epochs) > 1 and total_sample_ms
            else None
        ),
    }
    return result


def markdown(summary: dict[str, Any]) -> str:
    lines = [
        "# P1-05 contention summary",
        "",
        f"Samples: **{summary['sample_count']}**; observed span: **{summary['observed_duration_hours']:.2f} h**; "
        f"24 h minimum met: **{'yes' if summary['minimum_24h_met'] else 'no'}**.",
        "",
        "| Metric | Median | p10 | p90 | Worst observed | CV | Successful |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for metric, data in summary["metrics"].items():
        if "median" not in data:
            lines.append(f"| {metric} | n/a | n/a | n/a | n/a | n/a | 0 |")
            continue
        worst = data["min"] if data["preferred_direction"] == "higher" else data["max"]
        lines.append(
            f"| {metric} ({data['unit']}) | {data['median']:.4f} | {data['p10']:.4f} | "
            f"{data['p90']:.4f} | {worst:.4f} | {data['coefficient_of_variation']:.4f} | "
            f"{data['successful_samples']} |"
        )
    lines.extend(
        [
            "",
            f"Median sample runtime: **{summary['sampler_runtime']['median_ms']} ms**; "
            f"maximum: **{summary['sampler_runtime']['max_ms']} ms**.",
            "",
            "UTC-hour bucket medians and worst-observation timestamps are retained in the JSON summary for pattern/outlier analysis.",
        ]
    )
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("csv", type=Path)
    parser.add_argument("--interval-minutes", type=int, default=30)
    parser.add_argument("--markdown", action="store_true")
    args = parser.parse_args()

    summary = build_summary(args.csv, args.interval_minutes)
    if args.markdown:
        print(markdown(summary), end="")
    else:
        print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
