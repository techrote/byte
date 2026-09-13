# Qualification methodology

The goal is not to produce flattering benchmark numbers. The goal is to determine which tasks this specific shared Appbox can perform reliably, how variable performance is, and what limits should shape unattended automation.

## General rules

- Prefer representative work over synthetic saturation.
- Use bounded disposable data under a dedicated test directory such as `~/byte-test/`.
- Record start/end timestamps, tool versions, relevant quota/free-space state and test parameters.
- Repeat enough times to observe variance; do not infer a stable ratio from one run.
- Stop tests early if they materially affect interactive responsiveness, consume excessive quota, or appear abusive on the shared host.
- Clean up test artifacts after evidence is retained.
- Never benchmark outside the user's home/quota or write raw devices.

## Phase A — access/environment

Collect without modifying the host:

- `id`, groups, shell, home directory;
- kernel/OS information visible to the tenant;
- quota and filesystem free space;
- mounts/filesystem type where visible;
- `ulimit` and process/file descriptor limits;
- installed command/runtime availability;
- Docker/Compose availability;
- scheduling/user-service mechanisms (`cron`, `systemctl --user`, etc.) where present;
- network interface/routing information that does not expose secrets.

Host-level CPU/RAM figures are descriptive only and must not be labelled tenant entitlement.

## Phase B — storage

Questions:

1. Is sequential throughput sufficient for large artifact/image staging?
2. Are small-file/metadata operations tolerable for Git trees and extracted toolchains?
3. How variable is latency/throughput across time?

Suggested bounded test classes:

- create/read/delete one 1–4 GiB disposable file;
- sequential copy/read using ordinary filesystem tools or `fio` if available;
- create/stat/delete a bounded set of small files (for example 10k–50k, adjusted downward if slow);
- archive/extract a synthetic directory tree;
- measure p50/median and spread across repeated runs.

Do not attempt raw-device tests, direct I/O against unknown devices, or tests large enough to pressure other tenants.

## Phase C — network

The 10 Gbit figure is a shared host connection ceiling, not a tenant guarantee. Network qualification should answer practical questions while conserving the 3 TB outbound allowance.

- distinguish inbound (currently documented as unmetered) from outbound (counts against quota);
- prefer small/medium transfers with known endpoints;
- record transfer direction and bytes;
- verify the Bytesized panel/quota accounting behaviour;
- avoid multi-stream saturation tests unless a later issue explicitly justifies them;
- retain enough monthly headroom that qualification cannot impair ordinary use.

A default programme guardrail is to spend no more than **50 GB outbound** on qualification without an explicit issue decision.

## Phase D — CPU / utility work

CPU testing should model plausible Appbox work:

- SHA-256 hashing of a large local file;
- gzip/zstd/xz compression at moderate settings if available;
- archive extraction;
- Git bundle/repack operations;
- Python parsing/indexing of a synthetic manifest;
- small compilation task if a compiler is already available.

Use short repetitions and observe SSH responsiveness. Do not run indefinite prime/stress/mining-style loops.

## Phase E — rootless Docker

Verify:

- `docker info` works;
- hello-world smoke test;
- Compose availability;
- bind-mounted persistent data;
- restart policy behaviour;
- documented Traefik network existence;
- a harmless `whoami`-class test container receives HTTPS routing;
- container removal cleans up the public route;
- image/volume disk consumption can be measured and cleaned.

Do not interpret Docker-reported host CPU/RAM totals as tenant allocation.

## Phase F — contention/variance

Repeat a **small** representative suite over at least 24 hours, preferably covering several time windows:

- one short sequential read/write test;
- one metadata/small-file test;
- one hash/compression task;
- one HTTPS/local service latency check.

Report distribution and worst observed outliers rather than just fastest result.

## Success criteria

Qualification succeeds when we can answer:

- which workload classes are comfortably useful;
- which are possible but contention-sensitive;
- which should be avoided;
- practical storage/network rates and variance ranges;
- operational pain points;
- a safe quota/cleanup policy for unattended use.
