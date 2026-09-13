# Tools

Repository-managed utilities for safe Appbox qualification and operation.

- `appbox_probe.sh` — non-destructive first-contact probe; no transfer or stress workload.
- `validate_repo.py` — validates the RAG/workflow structure and scans text for obvious private-key material markers.

Implementation issues should add narrowly scoped tools here rather than leaving useful procedures only in shell history. Remote tools must remain bounded, shared-host appropriate, and safe to rerun where practical.
