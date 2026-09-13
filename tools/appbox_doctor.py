#!/usr/bin/env python3
"""Read-only, evidence-friendly health/capability snapshot for a Bytesized Appbox."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
from typing import Any, Callable

SCHEMA_VERSION = 1
TIMEOUT = 5.0
TOOLS = {
    "git": ["git", "--version"],
    "python3": ["python3", "--version"],
    "rsync": ["rsync", "--version"],
    "rclone": ["rclone", "version"],
    "tar": ["tar", "--version"],
    "gzip": ["gzip", "--version"],
    "zstd": ["zstd", "--version"],
    "xz": ["xz", "--version"],
    "sha256sum": ["sha256sum", "--version"],
    "curl": ["curl", "--version"],
    "sqlite3": ["sqlite3", "--version"],
    "gcc": ["gcc", "--version"],
    "g++": ["g++", "--version"],
    "make": ["make", "--version"],
    "cmake": ["cmake", "--version"],
    "node": ["node", "--version"],
    "npm": ["npm", "--version"],
    "ffmpeg": ["ffmpeg", "-version"],
    "jq": ["jq", "--version"],
    "go": ["go", "version"],
    "rustc": ["rustc", "--version"],
    "cargo": ["cargo", "--version"],
}
DOCKER_FAILURE_MARKERS = (
    "permission denied",
    "cannot connect to the docker daemon",
    "error during connect",
    "connection refused",
    "is the docker daemon running",
)


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def make_redactor() -> Callable[[str], str]:
    values = []
    home = os.environ.get("HOME", "")
    user = os.environ.get("USER", "") or os.environ.get("LOGNAME", "")
    if home and home != "/":
        values.append((home, "<HOME>"))
    if user and len(user) >= 2:
        values.append((user, "<USER>"))

    def redact(text: str) -> str:
        for source, replacement in values:
            text = text.replace(source, replacement)
        return text

    return redact


REDACT = make_redactor()


def run(cmd: list[str], timeout: float = TIMEOUT) -> dict[str, Any]:
    if shutil.which(cmd[0]) is None:
        return {"state": "missing", "rc": None, "stdout": "", "stderr": "command not found"}
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired:
        return {"state": "error", "rc": None, "stdout": "", "stderr": f"timeout after {timeout:g}s"}
    stdout = REDACT(proc.stdout.strip())
    stderr = REDACT(proc.stderr.strip())
    return {
        "state": "ok" if proc.returncode == 0 else "error",
        "rc": proc.returncode,
        "stdout": stdout,
        "stderr": stderr,
    }


def first_text(result: dict[str, Any]) -> str | None:
    text = result.get("stdout") or result.get("stderr") or ""
    return text.splitlines()[0].strip() if text.strip() else None


def home_shape() -> str:
    home = os.environ.get("HOME", "")
    if re.fullmatch(r"/home/[^/]+/[^/]+", home):
        return "/home/<provider-segment>/<account>"
    if re.fullmatch(r"/home/[^/]+", home):
        return "/home/<account>"
    return "other"


def os_name() -> str:
    path = Path("/etc/os-release")
    if path.is_file():
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if line.startswith("PRETTY_NAME="):
                return line.split("=", 1)[1].strip().strip('"')
    return platform.platform()


def check_quota() -> dict[str, Any]:
    result = run(["quota", "-s"])
    lines = [x.strip() for x in result.get("stdout", "").splitlines() if x.strip()]
    return {
        "state": result["state"],
        "summary": lines[-1] if lines else (first_text(result) or "quota unavailable"),
    }


def check_filesystem() -> dict[str, Any]:
    result = run(["df", "-PkT", os.environ.get("HOME") or "."])
    if result["state"] != "ok":
        return {"state": result["state"], "summary": first_text(result) or "df failed"}
    rows = [x.split() for x in result["stdout"].splitlines() if x.strip()]
    if len(rows) < 2 or len(rows[-1]) < 7:
        return {"state": "error", "summary": "unexpected df output"}
    row = rows[-1]
    try:
        return {
            "state": "ok",
            "filesystem_type": row[1],
            "blocks_kib": int(row[2]),
            "used_kib": int(row[3]),
            "available_kib": int(row[4]),
            "capacity": row[5],
            "mount": "<HOME_PARENT>",
        }
    except (ValueError, IndexError):
        return {"state": "error", "summary": "unparseable df output"}


def check_limits() -> dict[str, Any]:
    expressions = {
        "open_files": "ulimit -n",
        "processes": "ulimit -u",
        "stack_kib": "ulimit -s",
        "core_blocks": "ulimit -c",
    }
    values: dict[str, Any] = {"state": "ok"}
    errors = []
    for key, expr in expressions.items():
        result = run(["bash", "-lc", expr])
        if result["state"] != "ok":
            values["state"] = "error"
            errors.append(f"{key}: {first_text(result) or result['state']}")
            continue
        raw = result["stdout"].strip()
        values[key] = int(raw) if raw.isdigit() else raw
    if errors:
        values["errors"] = errors
    return values


def check_tools() -> dict[str, Any]:
    tools: dict[str, Any] = {}
    for name, cmd in TOOLS.items():
        result = run(cmd)
        if result["state"] == "missing":
            tools[name] = {"state": "missing"}
        elif result["state"] == "error":
            tools[name] = {"state": "error", "summary": first_text(result)}
        else:
            tools[name] = {"state": "ok", "version": first_text(result)}
    return tools


def check_scheduler() -> dict[str, Any]:
    cron_state = "ok" if shutil.which("crontab") else "missing"
    if shutil.which("systemctl") is None:
        systemd = {"state": "missing", "summary": "systemctl command not found"}
    else:
        result = run(["systemctl", "--user", "is-system-running"])
        systemd = {"state": result["state"], "summary": first_text(result) or "no user bus response"}
    return {
        "state": "ok" if cron_state == "ok" else "warning",
        "cron": {"state": cron_state},
        "systemd_user": systemd,
    }


def classify_docker_daemon(result: dict[str, Any]) -> dict[str, Any]:
    if result["state"] == "missing":
        return {"state": "missing", "summary": first_text(result)}
    combined = f"{result.get('stdout', '')}\n{result.get('stderr', '')}".lower()
    stdout = result.get("stdout", "").strip()
    bad_diagnostic = any(marker in combined for marker in DOCKER_FAILURE_MARKERS)
    if result.get("rc") != 0 or bad_diagnostic or not stdout:
        diagnostic = result.get("stderr", "") or result.get("stdout", "")
        summary = diagnostic.splitlines()[0].strip() if diagnostic.strip() else "daemon unavailable"
        return {"state": "error", "summary": summary}
    return {"state": "ok", "version": stdout.splitlines()[0].strip()}


def check_docker() -> dict[str, Any]:
    if shutil.which("docker") is None:
        return {
            "state": "missing",
            "client": {"state": "missing"},
            "compose": {"state": "missing"},
            "daemon": {"state": "missing"},
        }
    client = run(["docker", "--version"])
    compose = run(["docker", "compose", "version"])
    daemon_raw = run(["docker", "info", "--format", "{{.ServerVersion}}"], timeout=8.0)
    daemon = classify_docker_daemon(daemon_raw)
    return {
        "state": "ok" if daemon["state"] == "ok" else "warning",
        "client": {"state": client["state"], "version": first_text(client)},
        "compose": {"state": compose["state"], "version": first_text(compose)},
        "daemon": daemon,
    }


def check_directories() -> dict[str, Any]:
    home = Path(os.environ.get("HOME") or ".")
    return {
        "state": "ok",
        "entries": {name: (home / name).exists() for name in ["www", ".config", ".local", ".docker", "byte"]},
    }


def check_host_view() -> dict[str, Any]:
    result: dict[str, Any] = {
        "state": "ok",
        "warning": "shared-host view only; not tenant entitlement",
        "logical_cpus_visible": os.cpu_count(),
    }
    mem = run(["free", "-b"])
    if mem["state"] == "ok":
        rows = mem["stdout"].splitlines()
        if len(rows) > 1:
            cols = rows[1].split()
            if len(cols) > 1 and cols[1].isdigit():
                result["memory_bytes_visible"] = int(cols[1])
    return result


def snapshot(include_host: bool) -> dict[str, Any]:
    checks: dict[str, Any] = {
        "quota": check_quota(),
        "filesystem": check_filesystem(),
        "limits": check_limits(),
        "tools": check_tools(),
        "scheduler": check_scheduler(),
        "docker": check_docker(),
        "directories": check_directories(),
    }
    if include_host:
        checks["host_view"] = check_host_view()
    return {
        "schema_version": SCHEMA_VERSION,
        "generated_at_utc": utc_now(),
        "mode": "read_only",
        "platform": {
            "os": os_name(),
            "kernel": platform.release(),
            "architecture": platform.machine(),
            "shell": os.environ.get("SHELL", "unknown"),
            "home_shape": home_shape(),
        },
        "checks": checks,
    }


def capability_state(data: dict[str, Any], requirement: str) -> str:
    checks = data["checks"]
    if requirement == "quota":
        return checks["quota"]["state"]
    if requirement == "docker:daemon":
        return checks["docker"]["daemon"]["state"]
    if requirement == "scheduler:cron":
        return checks["scheduler"]["cron"]["state"]
    if requirement.startswith("tool:"):
        return checks["tools"].get(requirement.split(":", 1)[1], {"state": "missing"})["state"]
    return "unknown"


def requirements(data: dict[str, Any], requested: list[str]) -> tuple[str, list[dict[str, str]]]:
    failed = []
    for item in requested:
        state = capability_state(data, item)
        if state != "ok":
            failed.append({"requirement": item, "state": state})
    return ("fail" if failed else "pass"), failed


def print_human(data: dict[str, Any], requested: list[str]) -> None:
    checks = data["checks"]
    state, failed = requirements(data, requested)
    p = data["platform"]
    print(f"appbox-doctor schema={data['schema_version']} generated={data['generated_at_utc']} mode=read_only")
    print(f"platform: {p['os']} | kernel={p['kernel']} arch={p['architecture']} shell={p['shell']} home={p['home_shape']}")
    print(f"quota: {checks['quota']['state']} | {checks['quota'].get('summary', '')}")
    fs = checks["filesystem"]
    if fs["state"] == "ok":
        print(f"filesystem: ok | type={fs['filesystem_type']} used_kib={fs['used_kib']} available_kib={fs['available_kib']} capacity={fs['capacity']}")
    else:
        print(f"filesystem: {fs['state']} | {fs.get('summary', '')}")
    present = sorted(k for k, v in checks["tools"].items() if v["state"] == "ok")
    missing = sorted(k for k, v in checks["tools"].items() if v["state"] == "missing")
    errors = sorted(k for k, v in checks["tools"].items() if v["state"] == "error")
    print("tools-present: " + ",".join(present))
    print("tools-missing: " + (",".join(missing) if missing else "none"))
    print("tools-error: " + (",".join(errors) if errors else "none"))
    print(f"scheduler: cron={checks['scheduler']['cron']['state']} systemd_user={checks['scheduler']['systemd_user']['state']}")
    print(f"docker: client={checks['docker']['client']['state']} compose={checks['docker']['compose']['state']} daemon={checks['docker']['daemon']['state']}")
    print("known-dirs: " + " ".join(f"{k}={'yes' if v else 'no'}" for k, v in checks["directories"]["entries"].items()))
    if "host_view" in checks:
        hv = checks["host_view"]
        print(f"host-view: logical_cpus={hv.get('logical_cpus_visible')} memory_bytes={hv.get('memory_bytes_visible', 'unknown')} [NOT TENANT ENTITLEMENT]")
    print(f"requirements: {state}")
    for item in failed:
        print(f"  required {item['requirement']}: {item['state']}")


def self_test() -> int:
    home = os.environ.get("HOME", "")
    user = os.environ.get("USER", "") or os.environ.get("LOGNAME", "")
    cleaned = REDACT(f"path={home}/x user={user}")
    if (home and home in cleaned) or (user and len(user) >= 2 and user in cleaned):
        print("self-test: redaction failed", file=sys.stderr)
        return 1
    false_ok = {
        "state": "ok",
        "rc": 0,
        "stdout": "",
        "stderr": "permission denied while connecting to Docker daemon",
    }
    if classify_docker_daemon(false_ok)["state"] != "error":
        print("self-test: docker false-success regression", file=sys.stderr)
        return 1
    real_ok = {"state": "ok", "rc": 0, "stdout": "24.0.2", "stderr": ""}
    if classify_docker_daemon(real_ok)["state"] != "ok":
        print("self-test: docker success classification failed", file=sys.stderr)
        return 1
    fake = {
        "checks": {
            "quota": {"state": "ok"},
            "docker": {"daemon": {"state": "missing"}},
            "scheduler": {"cron": {"state": "ok"}},
            "tools": {"git": {"state": "ok"}},
        }
    }
    if requirements(fake, ["tool:git", "quota"])[0] != "pass" or requirements(fake, ["docker:daemon"])[0] != "fail":
        print("self-test: requirement handling failed", file=sys.stderr)
        return 1
    print("appbox-doctor self-test: PASS")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit structured JSON")
    parser.add_argument("--include-host", action="store_true", help="include explicitly labelled shared-host CPU/RAM visibility")
    parser.add_argument("--require", action="append", default=[], metavar="CAPABILITY", help="require quota, tool:<name>, scheduler:cron or docker:daemon")
    parser.add_argument("--self-test", action="store_true", help="run internal tests without probing")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()
    data = snapshot(args.include_host)
    state, failed = requirements(data, args.require)
    data["requirements"] = {"state": state, "failed": failed}
    if args.json:
        json.dump(data, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    else:
        print_human(data, args.require)
    return 2 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
