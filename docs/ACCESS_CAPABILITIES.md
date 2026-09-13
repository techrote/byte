# Access and useful-compute capability model

The programme needs to distinguish what can be done with limited shell/container access from what requires a real VPS. This document is the working capability map; completed issues should replace hypotheses with evidence.

## Access classes relevant to the Appbox

### SSH shell account

Expected capabilities:

- shell scripts and common Unix utilities;
- Git operations;
- checksums/hashing;
- compression/archive creation/extraction;
- Python or other user-space runtimes already available;
- binaries installed or compiled into the user's home directory where dependencies permit;
- rsync/rclone-style file movement where tools exist;
- cron or user-service scheduling if supported by the tenant;
- process supervision using user-level mechanisms.

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
| Rootless container services | Excellent platform fit | explicitly supported by provider |
| Lightweight databases/indexes | Good with durability caveat | useful state, but must remain exportable |
| Build small utilities | Good | user-space toolchains may work |
| Large C++ build farm | Poor/conditional | shared CPU and uncertain toolchain; test only if genuinely useful |
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
