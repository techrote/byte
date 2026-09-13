# Agent context

## Mission

Qualify and develop the user's existing Bytesized Appbox Lite into a useful, inexpensive, always-on limited-privilege node. Determine what work it can do reliably, automate that work, and preserve enough evidence that later infrastructure decisions can be based on measured behaviour rather than assumptions.

## Known instance facts

The user has already provisioned the box. The panel currently shows:

- 500 GB storage quota;
- 3.0 TB monthly bandwidth/upload allowance;
- SSH/FTP/VPN account credentials;
- a Bytesized hostname and shared public IP;
- monthly renewal.

Current Bytesized documentation says Appboxes provide SSH and rootless Docker, custom containers can use provider-managed HTTPS routing, the Appbox has no root access, the public IP is shared, Appbox Lite storage has no redundancy, and outbound traffic counts against the upload allowance.

These facts must be verified against the actual tenant where technically observable.

## Primary questions

1. How responsive and stable is SSH under ordinary and busy-host conditions?
2. What filesystem, quota, process, command, scheduler and user-service capabilities are actually available?
3. How consistent are HDD throughput, metadata latency and file-operation performance across time?
4. What sustained network performance is available without wasting quota?
5. Does rootless Docker/Compose work reliably, including restart persistence and Bytesized HTTPS routing?
6. Which low-to-moderate compute tasks are useful and neighbour-friendly on the shared host?
7. Can the box maintain Git mirrors, artifacts, manifests, caches and small services unattended?
8. Can all useful configuration/state be reconstructed or exported without relying on hidden manual setup?

## Programme invariants

- **Bytesized only for now.** Do not buy, provision, or integrate Hetzner, Netcup, AWS, another seedbox, or local worker infrastructure in this programme.
- **No secrets in Git.** The repository is public.
- **No root assumptions.** Work within the managed platform and rootless Docker model.
- **No performance fantasy from host metrics.** Shared-host totals are not tenant allocations.
- **No destructive benchmarking.** Storage tests use bounded disposable files inside an explicitly created test directory.
- **No sustained abusive compute.** The objective is useful shared-host work, not extracting every CPU cycle.
- **No sole-copy important data.** Appbox Lite is not redundant storage.
- **Evidence before optimisation.** Measure first, then choose roles.
- **Every issue closes through PR/checks/merge** as defined in `EXECUTION_PROTOCOL.md`.

## Current expected role

The most promising role is a warm staging/application tier: storage, manifests, Git mirrors/bundles, artifact/cache handling, hashing/compression, scheduled housekeeping, rootless containers, lightweight APIs/status services, and future bootstrap serving. This is a hypothesis to test, not an accepted conclusion.
