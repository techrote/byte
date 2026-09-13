#!/usr/bin/env python3
"""Repository consistency checks for techrote/byte.

Uses only the Python standard library so it can run on GitHub-hosted CI and on a
minimal development machine without installing dependencies.
"""

from __future__ import annotations

import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "README.md",
    "docs/RAG_INDEX.md",
    "docs/AGENT_CONTEXT.md",
    "docs/SCOPE.md",
    "docs/PROVIDER_MODEL.md",
    "docs/ACCESS_CAPABILITIES.md",
    "docs/ACCESS_BOOTSTRAP.md",
    "docs/SECURITY_MODEL.md",
    "docs/QUALIFICATION.md",
    "docs/OPERATIONS.md",
    "docs/EVIDENCE.md",
    "docs/EXECUTION_PROTOCOL.md",
    "docs/VERIFY.md",
    "docs/DECISIONS.md",
    "docs/ROADMAP.md",
    "docs/PLAN_REVIEW.md",
    "docs/workflow.json",
]

# Split the sensitive header strings so this scanner does not match its own
# source code while still detecting accidentally committed key material.
FORBIDDEN_TEXT = [
    "-----BEGIN " + "OPENSSH PRIVATE KEY" + "-----",
    "-----BEGIN " + "RSA PRIVATE KEY" + "-----",
    "-----BEGIN " + "EC PRIVATE KEY" + "-----",
]


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_required_files() -> None:
    missing = [p for p in REQUIRED if not (ROOT / p).is_file()]
    if missing:
        fail("required files missing: " + ", ".join(missing))


def validate_workflow() -> None:
    path = ROOT / "docs/workflow.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"cannot parse {path.relative_to(ROOT)}: {exc}")

    if data.get("schema_version") != 1:
        fail("workflow schema_version must be 1")
    if data.get("repository") != "techrote/byte":
        fail("workflow repository must be techrote/byte")
    if data.get("scope") != "bytesized-appbox-only":
        fail("workflow scope drifted from bytesized-appbox-only")

    tasks = data.get("tasks")
    if not isinstance(tasks, list) or not tasks:
        fail("workflow tasks must be a non-empty list")

    by_id: dict[str, dict] = {}
    for task in tasks:
        task_id = task.get("id")
        if not isinstance(task_id, str) or not task_id:
            fail("every task must have a non-empty string id")
        if task_id in by_id:
            fail(f"duplicate workflow task id: {task_id}")
        deps = task.get("depends_on")
        if not isinstance(deps, list) or not all(isinstance(x, str) for x in deps):
            fail(f"task {task_id}: depends_on must be a list of task ids")
        by_id[task_id] = task

    for task_id, task in by_id.items():
        for dep in task["depends_on"]:
            if dep not in by_id:
                fail(f"task {task_id}: unknown dependency {dep}")
            if dep == task_id:
                fail(f"task {task_id}: self dependency")

    visiting: set[str] = set()
    done: set[str] = set()

    def visit(task_id: str) -> None:
        if task_id in done:
            return
        if task_id in visiting:
            fail(f"workflow dependency cycle includes {task_id}")
        visiting.add(task_id)
        for dep in by_id[task_id]["depends_on"]:
            visit(dep)
        visiting.remove(task_id)
        done.add(task_id)

    for task_id in by_id:
        visit(task_id)

    print(f"workflow: {len(tasks)} tasks, dependency graph valid")


def validate_no_private_key_material() -> None:
    checked = 0
    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts:
            continue
        if path.stat().st_size > 2_000_000:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        checked += 1
        for marker in FORBIDDEN_TEXT:
            if marker in text:
                fail(f"private-key material marker found in {path.relative_to(ROOT)}")
    print(f"secret-hygiene marker scan: {checked} text files checked")


def main() -> None:
    validate_required_files()
    validate_workflow()
    validate_no_private_key_material()
    print("repository validation: PASS")


if __name__ == "__main__":
    main()
