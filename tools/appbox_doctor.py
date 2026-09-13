#!/usr/bin/env python3
"""Evidence-friendly, read-only health/capability snapshot for a Bytesized Appbox.

Default execution writes nothing and performs no transfer or stress test. Output is
redacted for common account identifiers. Optional requirements turn missing or
failed capabilities into a non-zero exit code for automation.
"""

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
from typing import Any

SCHEMA_VERSION = 1
DEFAULT_TIMEOUT = 5.0
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


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def redactor() -> tuple[callable, dict[str, str]]:
    home = os.environ.get("HOME", "")
    user = os.environ.get("USER", "") or os.environ.get("LOGNAME", "")
    replacements: list[tuple[str, str]] = []
    if home and home != "/":
        replacements.append((home, "<HOME>"))
    if user and len(user) >= 2:
        replacements.append((user, "<USER>"))

    def redact(text: str) -> str:
        out = text
        for source, replacement in replacements:
            out = out.replace(source, replacement)
        return out

    return redact, {"home": "<HOME>" if home else "unknown", "user": "<USER>" if user else "unknown"}


def run(cmd: list[str], *, timeout: float = DEFAULT_TIMEOUT) -> dict[str, Any]:
    redact, _ = redactor()
    executable = shutil.which(cmd[0])
    if executable is None:
        return {"state": "missing", "rc": None, "stdout": "", "stderr": "command not found"}
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=timeout,
            check=False,
            env=os.environ.copy(),
        )
    except subprocess.TimeoutExpired:
        return {"state": "error", "rc": None, "stdout": "", "stderr": f"timeout after {timeout:g}s"}
    stdout = redact(proc.stdout.strip())
    stderr = redact(proc.stderr.strip())
    return {
        "state": "ok" if proc.returncode == 0 else "error",
        "rc": proc.returncode,
        "stdout": stdout,
        "stderr": stderr,
    }


def first_line(result: dict[str, Any]) -> str | None:
    text = result.get("stdout") or result.get("stderr") or ""
    return text.splitlines()[0].strip() if text.strip() else None


def home_shape() -> str:
    home = os.environ.get("HOME", "")
    if re.fullmatch(r"/home/[^/]+/[^/]+", home):
        return "/home/<provider-segment>/<account>"
    if re.fullmatch(r"/home/[^/]+", home):
        return "/home/<account>"
    return "other"


def os_pretty_name() -> str:
    path = Path("/etc/os-release")
    if not path.is_file():
        return platform.platform()
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if line.startswith("PRETTY_NAME="):
            return line.split("=", 1)[1].strip().strip('"')
    return platform.platform()


def check_quota() -> dict[str, Any]:
    result = run(["quota", "-s"])
    item: dict[str, Any] = {"state": result["state"]}
    if result["state"] == "ok":
        lines = [line.strip() for line in result["stdout"].splitlines() if line.strip()]
        item["summary"] = lines[-1] if lines else "quota command succeeded"
    else:
        item["summary"] = first_line(result) or "quota unavailable"
    return item


def check_filesystem() -> dict[str, Any]:
    home = os.environ.get("HOME") or "."
    df = run(["df", "-PkT", home])
    if df["state"] != "ok":
        return {"state": df["state"], "summary": first_line(df) or "df failed"}
    lines = [x.split() for x in df["stdout"].splitlines() if x.strip()]
    if len(lines) < 2 or len(lines[-1]) < 7:
        return {"state": "error", "summary": "unexpected df output"}
    row = lines[-1]
    return {
        "state": "ok",
        "filesystem_type": row[1],
        "blocks_kib": int(row[2]),
        "used_kib": int(row[3]),
        "available_kib": int(row[4]),
        "capacity": row[5],
        "mount": "<HOME_PARENT>",
    }


def check_limits() -> dict[str, Any]:
    commands = {
        "open_files": "ulimit -n",
        "processes": "ulimit -u",
        "stack_kib": "ulimit -s",
        "core_blocks": "ulimit -c",
    }
    values: dict[str, Any] = {}
    state = "ok"
    errors: list[str] = []
    for key, expr in commands.items():
        result = run(["bash", "-lc", expr])
        if result["state"] != "ok":
            state = "error"
            errors.append(f"{key}: {first_line(result) or result['state']}")
        else:
            raw = result["stdout"].strip()
            values[key] = int(raw) if raw.isdigit() else raw
    values["state"] = state
    if errors:
        values["errors"] = errors
    return values


def check_tools() -> dict[str, Any]:
    output: dict[str, Any] = {}
    for name, cmd in TOOLS.items():
        result = run(cmd)
        if result["state"] == "missing":
            output[name] = {"state": "missing"}
        elif result["state"] == "error":
            output[name] = {"state": "error", "summary": first_line(result)}
        else:
            output[name] = {"state": "ok", "version": first_line(result)}
    return output


def check_scheduler() -> dict[str, Any]:
    cron = shutil.which("crontab") is not None
    if shutil.which("systemctl") is None:
        user_systemd = {"state": "missing", "summary": "systemctl command not found"}
    else:
        result = run(["systemctl", "--user", "is-system-running"])
        user_systemd = {
            "state": result["state"],
            "summary": first_line(result) or ("responded" if result["state"] == "ok" else "no user bus response"),
        }
    return {
        "state": "ok" if cron else "warning",
        "cron": {"state": "ok" if cron else "missing"},
        "systemd_user": user_systemd,
    }


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
    daemon = run(["docker", "info", "--format", "{{.ServerVersion}}"], timeout=8.0)
    overall = "ok" if daemon["state"] == "ok" else "warning"
    return {
        "state": overall,
        "client": {"state": client["state"], "version": first_line(client)},
        "compose": {"state": compose["state"], "version": first_line(compose)},
        "daemon": {"state": daemon["state"], "summary": first_line(daemon)},
    }


def check_directories() -> dict[str, Any]:
    home = Path(os.environ.get("HOME") or ".")
    names = ["www", ".config", ".local", ".docker", "byte"]
    return {
        "state": "ok",
        "entries": {name: (home / name).exists() for name in names},
    }


def check_host_view() -> dict[str, Any]:
    cpus = os.cpu_count()
    mem = run(["free", "-b"])
    result: dict[str, Any] = {
        "state": "ok",
        "warning": "shared-host view only; not tenant entitlement",
        "logical_cpus_visible": cpus,
    }
    if mem["state"] == "ok":
        lines = mem["stdout"].splitlines()
        if len(lines) > 1:
            cols = lines[1].split()
            if len(cols) >= 2 and cols[1].isdigit():
                result["memory_bytes_visible"] = int(cols[1])
    else:
        result["memory_state"] = mem["state"]
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
            "os": os_pretty_name(),
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
        name = requirement.split(":", 1)[1]
        return checks["tools"].get(name, {"state": "missing"})["state"]
    return "unknown"


def overall_state(data: dict[str, Any], requirements: list[str]) -> tuple[str, list[dict[str, str]]]:
    failed: list[dict[str, str]] = []
    for req in requirements:
        state = capability_state(data, req)
        if state != "ok":
            failed.append({"requirement": req, "state": state})
    return ("fail" if failed else "pass"), failed


def print_human(data: dict[str, Any], requirements: list[str]) -> None:
    checks = data["checks"]
    status, failed = overall_state(data, requirements)
    print(f"appbox-doctor schema={data['schema_version']} generated={data['generated_at_utc']} mode=read_only")
    p = data["platform"]
    print(f"platform: {p['os']} | kernel={p['kernel']} arch={p['architecture']} shell={p['shell']} home={p['home_shape']}")
    q = checks["quota"]
    print(f"quota: {q['state']} | {q.get('summary', '')}")
    fs = checks["filesystem"]
    if fs["state"] == "ok":
        print(f"filesystem: ok | type={fs['filesystem_type']} used_kib={fs['used_kib']} available_kib={fs['available_kib']} capacity={fs['capacity']}")
    else:
        print(f"filesystem: {fs['state']} | {fs.get('summary', '')}")
    tools = checks["tools"]
    present = sorted(k for k, v in tools.items() if v["state"] == "ok")
    missing = sorted(k for k, v in tools.items() if v["state"] == "missing")
    errors = sorted(k for k, v in tools.items() if v["state"] == "error")
    print("tools-present: " + ",".join(present))
    print("tools-missing: " + (",".join(missing) if missing else "none"))
    print("tools-error: " + (",".join(errors) if errors else "none"))
    sched = checks["scheduler"]
    print(f"scheduler: cron={sched['cron']['state']} systemd_user={sched['systemd_user']['state']}")
    docker = checks["docker"]
    print(f"docker: client={docker['client']['state']} compose={docker['compose']['state']} daemon={docker['daemon']['state']}")
    print("known-dirs: " + " ".join(f"{k}={'yes' if v else 'no'}" for k, v in checks["directories"]["entries"].items()))
    if "host_view" in checks:
        hv = checks["host_view"]
        print(f"host-view: logical_cpus={hv.get('logical_cpus_visible')} memory_bytes={hv.get('memory_bytes_visible', 'unknown')} [NOT TENANT ENTITLEMENT]")
    print(f"requirements: {status}")
    for item in failed:
        print(f"  required {item['requirement']}: {item['state']}")


def self_test() -> int:
    redact, _ = redactor()
    home = os.environ.get("HOME", "")
    user = os.environ.get("USER", "") or os.environ.get("LOGNAME", "")
    sample = f"path={home}/x user={user}"
    clean = redact(sample)
    if home and home in clean:
        print("self-test: home redaction failed", file=sys.stderr)
        return 1
    if user and len(user) >= 2 and user in clean:
        print("self-test: user redaction failed", file=sys.stderr)
        return 1
    fake = {
        "checks": {
            "quota": {"state": "ok"},
            "docker": {"daemon": {"state": "missing"}},
            "scheduler": {"cron": {"state": "ok"}},
            "tools": {"git": {"state": "ok"}},
        }
    }
    if capability_state(fake, "tool:git") != "ok" or capability_state(fake, "tool:nope") != "missing":
        print("self-test: capability state failed", file=sys.stderr)
        return 1
    if overall_state(fake, ["tool:git", "quota"])[0] != "pass":
        print("self-test: requirement pass failed", file=sys.stderr)
        return 1
    if overall_state(fake, ["docker:daemon"])[0] != "fail":
        print("self-test: requirement failure failed", file=sys.stderr)
        return 1
    print("appbox-doctor self-test: PASS")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", action="store_true", help="emit structured JSON instead of concise text")
    parser.add_argument("--include-host", action="store_true", help="include explicitly labelled shared-host CPU/RAM visibility")
    parser.add_argument(
        "--require",
        action="append",
        default=[],
        metavar="CAPABILITY",
        help="require capability (quota, tool:<name>, scheduler:cron, docker:daemon); repeatable",
    )
    parser.add_argument("--self-test", action="store_true", help="run non-probing internal tests")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.self_test:
        return self_test()
    data = snapshot(args.include_host)
    status, failed = overall_state(data, args.require)
    data["requirements"] = {"state": status, "failed": failed}
    if args.json:
        json.dump(data, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    else:
        print_human(data, args.require)
    return 2 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
