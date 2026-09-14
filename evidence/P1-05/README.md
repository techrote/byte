# P1-05 — Shared-host contention and variance sampling

**Status:** sampling implementation prepared; live 24–48 hour evidence is required before this issue may be completed or merged.

## Sampling envelope

The reusable `tools/sample_contention.sh` sampler is intentionally much smaller than the one-off qualification workloads from P1-03/P1-04. The default live schedule is one sample every **30 minutes for 48 hours**.

Each sample performs:

- one ordinary **64 MiB** sequential zero-file write with `fdatasync`, then deletes it;
- create/stat-read/delete of **1,000 × 128-byte** small files in a shallow directory tree;
- SHA-256 of a retained **32 MiB** seed file;
- zstd level 3 compression of the same seed to `/dev/null`;
- one rootless `docker info` response-latency observation plus running-container count;
- one tiny HTTPS timing request through an already-running provider-managed `*.bysh.me` route discovered from Docker labels without storing or printing the tenant hostname;
- quota and filesystem-free-space snapshots.

A single persistent 32 MiB seed and small CSV/log files are retained. Per-sample disposable state is trap-cleaned. Peak temporary storage is roughly 66 MiB plus filesystem metadata. Over 48 hours at 30-minute spacing the sampler is expected to perform roughly 96 short bursts and about 6 GiB of cumulative sequential test writes, with negligible network transfer compared with P1-04.

## Guardrails

- Atomic lock prevents overlapping samples; locks older than 15 minutes are treated as stale and recovered.
- Each sample refuses active work below 2 GiB filesystem headroom or, where quota is readable, below 2 GiB quota headroom.
- The sampling window self-expires; cron invocations after the end timestamp perform no workload.
- No raw devices, direct I/O, cache dropping, multistream saturation, public test routes, privileged containers or continuous CPU load.
- Existing provider-managed applications are observed only through counts/latency; their configuration is not modified.
- The HTTPS target hostname is not written to the CSV or programme logs.
- Cron installation/removal touches only the line carrying the exact `# byte-p1-05-contention` marker.

## Result processing

`tools/summarize_contention.py` produces:

- median, p10, p90, p95, minimum and maximum;
- coefficient of variation;
- worst-observation timestamps;
- UTC-hour bucket medians for visible time-of-day patterns;
- sample coverage/gaps and 24-hour acceptance-gate status;
- sampler duty-cycle estimate and storage/quota range.

The final evidence set will add the public-safe raw CSV and generated summary after at least 24 hours of real samples exist. Until then this PR must remain draft and must not close #9.
