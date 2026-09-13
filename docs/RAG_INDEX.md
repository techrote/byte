# RAG index

Purpose: retrieval-oriented index for agents executing `techrote/byte` issues. Load the smallest relevant set rather than the entire repository.

| Document | Retrieve when the task concerns | High-signal terms |
|---|---|---|
| `AGENT_CONTEXT.md` | mission, current instance, programme invariants | Bytesized, Appbox Lite, 500 GB, 3 TB, shared host |
| `SCOPE.md` | whether proposed work belongs in this programme | Bytesized-only, deferred, external provider |
| `PROVIDER_MODEL.md` | provider capabilities and constraints | rootless Docker, shared IP, no root, HTTPS, quota |
| `ACCESS_CAPABILITIES.md` | what SSH/Docker/managed access can be used for | shell, Compose, cron, ports, compute envelope |
| `ACCESS_BOOTSTRAP.md` | giving trusted automation a remote execution route | SSH key, GitHub secrets, known hosts, Actions |
| `SECURITY_MODEL.md` | credentials, exposure, public repo, service boundaries | SSH key, secrets, reverse proxy, least privilege |
| `QUALIFICATION.md` | benchmark/test methodology | bounded load, contention, HDD, network, variance |
| `OPERATIONS.md` | directory layout, lifecycle, cleanup, monitoring | quota, logs, manifests, restart, maintenance |
| `EVIDENCE.md` | what outputs and metadata must be retained | raw output, timestamp, redaction, provider state |
| `EXECUTION_PROTOCOL.md` | branch/PR/check/merge requirements for every issue | autonomous, PR, CI, merge, reconciliation |
| `VERIFY.md` | final acceptance gates | recovery, Docker, HTTPS, quota, soak, security |
| `DECISIONS.md` | accepted/rejected/deferred architectural choices | ADR, rationale, revisit |
| `ROADMAP.md` | phase ordering and dependency intent | P0, P1, P2, P3, P4, P5 |
| `PLAN_REVIEW.md` | corrections made before execution | review, improvement, risk, sequencing |
| `workflow.json` | machine-readable stable task IDs/dependencies | task id, depends_on, phase |

## Retrieval rules

1. Repository evidence produced by completed issues outranks assumptions from chat or marketing pages.
2. Provider claims are constraints to verify, not measured performance guarantees.
3. Do not infer CPU allocation from `nproc`, `free`, `docker stats`, or host-wide metrics on the shared platform.
4. Do not treat the Appbox as an authoritative backup: the current plan advertises no storage redundancy.
5. The current programme is Bytesized-only. External backup providers, VPSs, and local compute integration remain deferred unless scope is explicitly amended.
6. Never commit passwords, API tokens, SSH private keys, session cookies, application secrets, or unredacted credential-bearing configuration.
7. Prefer small bounded tests that answer a concrete question; do not abuse shared CPU/I/O/network resources.
8. Every implementation issue follows `EXECUTION_PROTOCOL.md` through PR, automated checks, and merge.
