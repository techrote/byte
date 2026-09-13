# Appbox doctor and evidence harness

P0-03 provides reusable, low-impact tooling for later qualification and operations work.

## `tools/appbox_doctor.py`

The doctor produces a concise health/capability snapshot. Default execution is read-only: it does not create files, transfer data, install software, enumerate arbitrary home-directory contents, or run stress tests.

Examples:

```bash
python3 tools/appbox_doctor.py
python3 tools/appbox_doctor.py --json
python3 tools/appbox_doctor.py --require quota --require tool:git
python3 tools/appbox_doctor.py --require docker:daemon
```

Supported requirement forms are `quota`, `tool:<name>`, `scheduler:cron`, and `docker:daemon`. A required capability that is missing, failed or unknown causes exit code 2. Optional capability failures remain visible in output without making the default snapshot fail.

The doctor distinguishes:

- `ok` — the command/capability was observed successfully;
- `missing` — the executable/capability is absent;
- `error` — the command exists but failed or timed out;
- `warning` — an aggregate capability is partially available and needs interpretation.

Common home/account identifiers are redacted from captured command text. Shared-host CPU/RAM visibility is omitted by default; `--include-host` enables it with an explicit non-entitlement warning.

## `tools/evidence_capture.py`

The evidence harness is an explicit-write wrapper around the doctor. It writes nothing unless `--output-dir` is supplied.

```bash
python3 tools/evidence_capture.py --output-dir evidence/PX-YY/raw
python3 tools/evidence_capture.py --output-dir evidence/PX-YY/raw --require quota --require tool:git
```

The destination receives:

- `doctor.json` — structured doctor output;
- `doctor.stderr.txt` — bounded diagnostic stderr;
- `metadata.json` — UTC timestamps, exit code, requested requirements, file sizes and SHA-256 hashes.

The harness deliberately does not dump environment variables, shell history, credentials, arbitrary file contents, or provider session data. It refuses a non-empty output directory unless `--force` is explicit.

## CI validation

`tools/validate_repo.py` compiles all Python files under `tools/` and executes the doctor/harness self-tests. Shell tooling continues to receive `bash -n` validation from repository CI.

## Evidence workflow

For later issues, prefer this sequence:

1. run the doctor without writes for preflight;
2. add `--require` checks for capabilities genuinely required by the issue;
3. use the evidence harness only when a committed evidence snapshot is useful;
4. review/redact generated files before committing them;
5. remove disposable remote test data/services according to the issue-specific cleanup plan.

Performance, storage and network stress/throughput testing is intentionally outside this toolkit and remains scoped to the dedicated P1 qualification issues.
