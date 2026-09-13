# P0-03 — Appbox doctor and evidence harness

**Result:** pass.

The reusable doctor/evidence toolkit was validated in repository CI and the exact reviewed doctor revision was executed read-only on the actual Appbox.

## Verification

Final live acceptance used GitHub Actions run `34786617679`. The temporary execution wrapper fetched `tools/appbox_doctor.py` from immutable commit `58d0a3a62c183b3326c7d66fbf4ced1c0a0a9755`, ran it inside the workflow-created temporary directory, and left no persistent test data.

Observed doctor behaviour:

- schema version 1 and UTC timestamp emitted;
- platform/home identifiers were evidence-friendly and the home path was reduced to `/home/<provider-segment>/<account>`;
- quota and filesystem checks succeeded;
- required capabilities `quota` and `tool:git` passed;
- installed/missing tool state was reported explicitly;
- cron was `ok` while the noninteractive user-systemd check was `error`;
- Docker client and Compose were `ok`, while daemon access was correctly classified `error`;
- `--require docker:daemon` produced the intended requirement failure and exit code 2;
- the ordinary doctor snapshot remained successful because Docker daemon access was not a default required capability.

## Defect found during qualification

The first live doctor revision trusted the Docker command's zero exit status even when it emitted a permission-denied socket diagnostic. That misclassified the daemon as available. P0-03 added explicit daemon diagnostic validation plus a regression self-test, then repeated the live acceptance successfully.

This distinction is important for later work: **command installed**, **command failed**, and **capability missing** are separate states.

## CI / self-tests

`tools/validate_repo.py` now compiles Python tooling and runs the doctor and evidence-harness self-tests in repository CI. The doctor regression self-test includes the Docker zero-exit/permission-denied case.

## Evidence harness

`tools/evidence_capture.py` is explicit-write only: no files are created unless an output directory is supplied. It captures structured doctor output, bounded stderr, timestamps, exit status, sizes and SHA-256 hashes without intentionally dumping environment variables or credentials.

## Cleanup

The Appbox execution used only the existing remote lane's temporary directory. The lane removed remote temporary material and runner SSH material after the successful run. No long-lived service, benchmark data or transfer-test data was created.
