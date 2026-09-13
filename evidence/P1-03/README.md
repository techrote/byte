# P1-03 — HDD throughput, metadata and archive qualification

**Result:** pass with caveats.

A bounded storage workload was executed on the real Appbox through the trusted GitHub Actions SSH lane. The canonical active run was Actions run `34787914479` (remote execution commit `021833d7094e089fdffda36ccdaffbca9796a1b3`) from 2026-09-13T22:49:40Z to 22:50:59Z. A separate read-only cleanup verification passed in run `34788058042` at 22:52:45Z.

## Workload

The committed `tools/qualify_storage.sh` defaults were used:

- 3 repetitions;
- 1 GiB sequential file create with `fdatasync`, buffered read, copy plus `sync`, SHA-256 and deletion;
- 5,000-file create, stat/read and delete cycles;
- 2,048-file synthetic archive tree at 32 KiB/file (64 MiB payload), with a 50/50 deterministic pseudo-random/text mixture;
- tar create/extract and zstd level-3 compress/decompress;
- quota and filesystem free-space snapshots before and after;
- an independent SSH connection attempt while the sequential phase was active;
- explicit post-run verification that no P1-03 marker or disposable test tree remained.

Environment: ext4 home filesystem; GNU coreutils 8.32 `dd`; GNU tar 1.34; zstd 1.4.8; Python 3.10.12.

## Results

| Task | Median | Range | Interpretation |
| --- | ---: | ---: | --- |
| 1 GiB create + `fdatasync` | 144.9 MiB/s | 136.8–151.2 MiB/s | Useful durable-write task shape |
| 1 GiB copy + `sync` | 147.3 MiB/s | 144.7–181.8 MiB/s | Useful staging/copy task shape |
| 1 GiB SHA-256 | 111.1 MiB/s | 105.6–111.9 MiB/s | Comfortable local hashing |
| 1 GiB buffered read | 2723 MiB/s | 2404–2798 MiB/s | **Page-cache dominated; not HDD throughput** |
| 5,000 small-file create | 8.68k files/s | 8.64–9.33k files/s | Comfortable in this sample |
| 5,000 small-file stat/read | 22.1k files/s | 19.1–23.9k files/s | Comfortable in this sample |
| 5,000 small-file delete | 59.5k files/s | 58.8–66.7k files/s | Comfortable in this sample |
| 64 MiB tar create | 115.9 MiB/s | 115.5–122.4 MiB/s | Comfortable archive creation |
| 64 MiB tar extract | 328.2 MiB/s | 315.3–363.6 MiB/s | Cache-influenced; useful task timing, not raw-disk rate |
| zstd -3 compress | 383.2 MiB/s | 374.3–390.2 MiB/s | CPU/cache dominated at this payload size |
| zstd decompress | 310.7 MiB/s | 303.3–338.6 MiB/s | CPU/cache dominated at this payload size |

The synthetic 64 MiB archive compressed to 33,692,587 bytes (50.21%), avoiding the unrealistically compressible all-text workload used in the preliminary pass.

## Responsiveness

A second fresh SSH connection completed successfully while the sequential benchmark marker was active. End-to-end connection/command time from the GitHub Actions runner was **1,982 ms**. This demonstrates that interactive access remained available during the bounded storage load; it is not a general latency benchmark.

## Quota and cleanup

Before the canonical run, the relevant quota row reported 13,771,476 KiB-blocks used, a 500,000,000-block soft quota and a 550,000,000-block hard limit. Immediately after cleanup it reported 13,771,472 blocks used. The four-block decrease is ordinary concurrent/account filesystem churn rather than test storage; importantly, no test allocation remained.

The independent verification run subsequently reported the same 13,771,472 used blocks and explicitly confirmed:

- `running_marker_present=no`;
- `disposable_test_tree_present=no`;
- `cleanup_verify=pass`.

## Interpretation

For the intended warm-artifact/cache/staging role, this one time-window sample is comfortably useful: durable sequential writes/copies are around the mid-100 MiB/s range, hashing is around 111 MiB/s, and bounded metadata/archive workloads complete quickly. The result does **not** establish guaranteed throughput or tenant entitlement: this is shared storage and the 24–48 hour variance envelope belongs to P1-05.

The buffered read and archive-extract figures must not be presented as physical-disk throughput because Linux page cache materially influences them.

## Evidence

- `summary.json` — machine-readable parameters, samples, medians/ranges and cleanup state.
- `raw.txt` — public-safe canonical measurements and verification outputs extracted from the trusted-run logs.
- GitHub Actions active run: `34787914479`.
- GitHub Actions cleanup verification: `34788058042`.
