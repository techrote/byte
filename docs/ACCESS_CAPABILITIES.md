# Access and useful-compute capability model

The programme needs to distinguish what can be done with limited shell/container access from what requires a real VPS. This document is the working capability map; completed issues should replace hypotheses with evidence.

## Measured P0-02 baseline

The first read-only inventory of the actual tenant confirmed:

- Ubuntu 22.04.5 LTS with Python 3.10, Git, rsync/rclone, archive/compression/hash tools, SQLite, GCC/G++/Make/CMake, Node/npm and FFmpeg already available;
- `jq`, Go and Rust absent from PATH;
- ext4 home storage with a directly visible user quota;
- cron/crontab present;
- no usable user-systemd bus in the noninteractive probe, which was later resolved operationally by P1-01 in favour of cron for periodic work;
- Docker client and Compose installed, while the default context did not expose an accessible daemon at that time; P1-02 later activated and qualified the provider rootless path;
- host-visible CPU, RAM and backing-filesystem totals are shared-host observations only, not tenant entitlement.

Detailed evidence is in `evidence/P0-02/`.

## Access classes relevant to the Appbox

### SSH shell account

Confirmed capabilities:

- shell scripts and common Unix utilities;
- Git operations;
- checksums/hashing;
- compression/archive creation/extraction;
- Python and Node user-space runtimes;
- small native builds using the installed GCC/G++/Make/CMake toolchain where dependencies permit;
- binaries installed into the user's home directory where dependencies permit;
- rsync/rclone-style file movement;
- cron scheduling;
- bounded detached jobs using the P1-01 operating model.

Constraints:

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

P1-02 proved this path on the actual tenant after the provider-supported activation step of installing a Docker-backed app from the Bytesized panel:

- Docker server/client **24.0.2** and Compose **v2.18.1** work through the per-user rootless socket `~/.docker/run/docker.sock`;
- Docker reports the `rootless` security option;
- the provider `traefik_${USER}` network exists;
- Compose configuration/startup works;
- bind-mounted state survived complete container recreation;
- `restart: unless-stopped` was observed and the service/data survived a safe container restart;
- a temporary custom web service was externally reachable through provider-managed HTTPS with valid TLS;
- no raw public port was required;
- exact test cleanup returned Docker to the original post-activation image/container footprint.

The ordinary default `/var/run/docker.sock` remains inaccessible. Noninteractive programme automation should explicitly set:

```sh
DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
```

The daemon also reports that rootless mode is running **without cgroups** in this environment. Do not interpret Docker `--cpus`, `--memory`, `docker stats`, host CPU count or host RAM totals as enforceable tenant allocation.

Not suitable as an assumption for:

- GPU/CUDA workloads;
- privileged networking;
- kernel features;
- enforced per-container CPU/RAM quotas;
- trustworthy benchmarking.

### Provider reverse proxy / automatic HTTPS

P1-02 proved the documented provider path on the actual tenant: a custom container joined `traefik_${USER}`, exposed no raw host port, and returned HTTP 200 with successful certificate/hostname verification from an external GitHub-hosted runner.

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
| Rootless container services | Good with shared-host caveat | actual Docker/Compose/persistence/restart/HTTPS path is proven; cgroup resource enforcement is unavailable |
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
