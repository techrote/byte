# Access and useful-compute capability model

The programme needs to distinguish what can be done with limited shell/container access from what requires a real VPS. This document is the working capability map; completed issues should replace hypotheses with evidence.

## Measured P0-02 baseline

The first read-only tenant inventory confirmed a broad user-space toolchain on the actual Appbox:

- Ubuntu 22.04.5 LTS, Python 3.10, Git, rsync, rclone, archive/compression/hash tools, SQLite, GCC/G++, Make, CMake, Node/npm and FFmpeg are present;
- `jq`, Go and Rust are not currently on PATH;
- the home filesystem is ext4 and `quota` exposes the tenant capacity boundary directly;
- cron/crontab commands are present;
- a user-systemd bus did not respond in the noninteractive probe and remains a P1-01 qualification question;
- Docker client 24.0.2 and Compose 2.18.1 are installed, but the default context did not expose an accessible daemon in P0-02, so rootless Docker remains unproven until P1-02;
- host-visible CPU, RAM and backing-filesystem totals are shared-host observations only, never tenant entitlement.

Detailed evidence is in `evidence/P0-02/`.

## Access classes relevant to the Appbox

### SSH shell account

Confirmed or expected capabilities:

- shell scripts and common Unix utilities;
- Git operations;
- checksums/hashing;
- compression/archive creation/extraction;
- Python and Node user-space runtimes already available;
- small native builds using the installed GCC/G++/Make/CMake toolchain where dependencies permit;
- binaries installed into the user's home directory where dependencies permit;
- rsync/rclone-style file movement;
- cron scheduling;
- user-service/process supervision where later qualification proves a suitable mechanism.

Expected constraints:

- no package-manager root operations;
- no kernel configuration;
- no host firewall/routing changes;
- no privileged ports;
- no reliable hardware/host-resource ownership information from ordinary host metrics.

### Rootless Docker / Compose

Best suited to:

- packaging lightweight persistent services;
- small HTTP APIs and status endpoints;
- simple databases or indexes whose data remains within quota and is not sole-copy important data;
- queue/controller helpers;
- web UIs;
- reproducible utility applications;
- bounded workers whose CPU behaviour is neighbour-friendly.

P0-02 confirmed the Docker client and Compose plugin only. A working rootless daemon and provider integration must be demonstrated by P1-02 before this capability is treated as available.

Not suitable as an assumption for:

- GPU/CUDA workloads;
- privileged networking;
- kernel features;
- enforced per-container CPU/RAM quotas;
- trustworthy benchmarking.

### Provider reverse proxy / automatic HTTPS

Best suited to:

- lightweight authenticated web endpoints;
- health/status interfaces;
- artifact/manifests browsing;
- future orchestration callbacks where exposing a service is justified.

Security rule: an automatically issued TLS certificate does **not** make an application safe. Exposed services still require application authentication/authorization where sensitive actions or information exist.

## Task suitability matrix

| Task class | Suitability | Reason |
|---|---|---|
| Store warm artifacts/caches | Excellent | large inexpensive HDD quota; persistent account |
| Git mirrors/bundles | Excellent | low sustained CPU; file/network oriented |
| Hash/checksum/index files | Good | bounded CPU, valuable near stored data |
| Compression/decompression | Good when bounded | saves transfer/storage; avoid indefinite CPU saturation |
| File format conversion | Good if modest | data-local work; measure CPU impact |
| Scheduled cleanup/retention | Excellent | persistent always-on role |
| Small Python services | Good | little privilege required |
| Rootless container services | Promising, evidence-gated | provider documents support; actual daemon path still needs P1-02 proof |
| Lightweight databases/indexes | Good with durability caveat | useful state, but must remain exportable |
| Build small utilities | Good | GCC/G++/Make/CMake are already present |
| Large C++ build farm | Poor/conditional | shared CPU; test only if genuinely useful |
| Cybersand authoritative performance tests | Unsuitable | shared contention invalidates reference timing |
| Long synthetic stress | Unsuitable | unfair to neighbours and low informational value |
| VPN/router/firewall node | Unsuitable | no root; VPN-style containers unverified |
| Sole backup of important data | Unsuitable | no disk redundancy |

## Decision rule for new tasks

Before adding a workload, ask:

1. Can it run without root/kernel/network privileges?
2. Is it bursty, I/O-oriented, or latency-tolerant rather than sustained CPU-heavy?
3. Is failure/restart acceptable?
4. Can its state be exported/recreated?
5. Does it fit comfortably inside storage and monthly outbound budgets?
6. If public-facing, does it have proper application authentication?

If several answers are no, the task belongs on a different future resource class rather than being forced onto the Appbox.
