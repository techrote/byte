# Roadmap

Stable task IDs below are used in `workflow.json` and issue titles. Actual GitHub issue numbers are reconciled after publication.

## Phase P0 — Establish safe control and ground truth

| ID | Task | Depends on |
|---|---|---|
| P0-01 | Establish secure remote execution / SSH-key bootstrap | — |
| P0-02 | Capture tenant environment, quota and capability inventory | P0-01 |
| P0-03 | Build reusable Appbox doctor/probe toolkit and evidence harness | P0-02 |

Exit condition: we can administer the box without routinely using a password, know what the tenant can actually do, and have reusable non-destructive probes.

## Phase P1 — Qualify the shared platform

| ID | Task | Depends on |
|---|---|---|
| P1-01 | Qualify SSH/session/scheduling/user-service capabilities | P0-03 |
| P1-02 | Qualify rootless Docker, Compose, persistence and managed HTTPS | P0-03 |
| P1-03 | Qualify HDD throughput, metadata and archive operations | P0-03 |
| P1-04 | Qualify network transfer behaviour and quota accounting conservatively | P0-03 |
| P1-05 | Sample contention/variance across 24–48 hours | P1-01, P1-02, P1-03, P1-04 |

Exit condition: useful workload classes and their variance/limits are evidenced rather than assumed.

## Phase P2 — Turn capabilities into useful infrastructure

| ID | Task | Depends on |
|---|---|---|
| P2-01 | Establish `~/byte` layout, capacity guardrails, logs and cleanup | P1-03, P1-05 |
| P2-02 | Build artifact staging + content manifest/checksum tooling | P2-01 |
| P2-03 | Build Git mirror/bundle cache workflow | P2-01 |
| P2-04 | Deploy a minimal authenticated health/status service via rootless Docker | P1-02, P2-01 |
| P2-05 | Implement scheduled maintenance and health reporting | P1-01, P2-01, P2-04 |

Exit condition: the box is already useful without any external VPS/storage dependency.

## Phase P3 — Security, automation and reconstructability

| ID | Task | Depends on |
|---|---|---|
| P3-01 | Harden SSH, service exposure, credentials and Docker operation | P2-04, P2-05 |
| P3-02 | Implement a lightweight bounded job/orchestration helper | P2-02, P2-03, P3-01 |
| P3-03 | Build portable export/reconstruction bundle and perform local restore rehearsal | P2-01, P2-02, P2-03, P3-01 |

Exit condition: routine jobs can run safely and useful state is reconstructable without undocumented manual setup.

## Phase P4 — Determine practical role boundaries

| ID | Task | Depends on |
|---|---|---|
| P4-01 | Map useful compute/task envelope with representative real workloads | P1-05, P2-02, P2-03 |
| P4-02 | Define and build a warm bootstrap/cache bundle format for future consumers | P3-03, P4-01 |

Important: P4-02 creates only the Appbox-side format/artifacts. It does **not** provision or integrate a VPS or other external consumer.

## Phase P5 — Operational qualification and handover

| ID | Task | Depends on |
|---|---|---|
| P5-01 | Run a seven-day soak/availability/quota/cleanup audit | P2-05, P3-02, P3-03, P4-01 |
| P5-02 | Programme-wide verification, documentation reconciliation and handover | all applicable preceding tasks |

Exit condition: we know whether the Appbox is worth retaining, exactly what role it should play, and how to rebuild/export it.

## Parallelism

After P0-03, P1-01 through P1-04 can proceed independently. P2-02 and P2-03 can also proceed in parallel once P2-01 is complete. Avoid parallel heavy storage/network qualification on the remote host because overlapping tests would contaminate measurements and increase neighbour impact.

## Scope guard

No roadmap item provisions external infrastructure. If later work adds Hetzner/Netcup/local-node integration, create a new programme phase or repository issue set after P5 evidence is available.
