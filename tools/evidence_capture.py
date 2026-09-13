#!/usr/bin/env python3
"""Small explicit-write evidence harness for Appbox doctor snapshots.

The harness never writes unless --output-dir is supplied. It captures only the
structured doctor output and minimal provenance; it does not dump environment
variables, credentials, arbitrary home content, or shell history.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DOCTOR = ROOT / "tools" / "appbox_doctor.py"


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def ensure_output_dir(path: Path, force: bool) -> None:
    if path.exists():
        if not path.is_dir():
            raise SystemExit(f"output path exists and is not a directory: {path}")
        if any(path.iterdir()) and not force:
            raise SystemExit(f"output directory is not empty: {path}; use --force to replace harness files")
    path.mkdir(parents=True, exist_ok=True)


def capture_doctor(output_dir: Path, include_host: bool, requirements: list[str], force: bool) -> int:
    ensure_output_dir(output_dir, force)
    cmd = [sys.executable, str(DOCTOR), "--json"]
    if include_host:
        cmd.append("--include-host")
    for req in requirements:
        cmd.extend(["--require", req])

    started = utc_now()
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    finished = utc_now()

    doctor_path = output_dir / "doctor.json"
    stderr_path = output_dir / "doctor.stderr.txt"
    metadata_path = output_dir / "metadata.json"

    doctor_path.write_bytes(proc.stdout)
    stderr_path.write_bytes(proc.stderr)
    metadata: dict[str, Any] = {
        "schema_version": 1,
        "capture_type": "appbox-doctor",
        "started_at_utc": started,
        "finished_at_utc": finished,
        "exit_code": proc.returncode,
        "requirements": requirements,
        "include_host": include_host,
        "artifacts": {
            "doctor.json": {"sha256": sha256(proc.stdout), "bytes": len(proc.stdout)},
            "doctor.stderr.txt": {"sha256": sha256(proc.stderr), "bytes": len(proc.stderr)},
        },
        "privacy": "No environment dump or credential material intentionally captured.",
    }
    metadata_path.write_text(json.dumps(metadata, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"evidence written to {output_dir}")
    return proc.returncode


def self_test() -> int:
    if not DOCTOR.is_file():
        print("self-test: doctor script missing", file=sys.stderr)
        return 1
    probe = b"abc"
    if sha256(probe) != "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad":
        print("self-test: sha256 mismatch", file=sys.stderr)
        return 1
    print("evidence-capture self-test: PASS")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true", help="run internal tests without writing")
    parser.add_argument("--output-dir", type=Path, help="explicit destination for doctor.json and metadata")
    parser.add_argument("--include-host", action="store_true", help="ask doctor for labelled shared-host visibility")
    parser.add_argument("--require", action="append", default=[], help="doctor capability requirement; repeatable")
    parser.add_argument("--force", action="store_true", help="allow replacing harness-owned files in a non-empty directory")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()
    if args.output_dir is None:
        print("--output-dir is required for capture; no files written", file=sys.stderr)
        return 2
    return capture_doctor(args.output_dir, args.include_host, args.require, args.force)


if __name__ == "__main__":
    raise SystemExit(main())
