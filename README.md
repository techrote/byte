# byte

Repository-native qualification and development programme for the user's **Bytesized Appbox Lite**.

The current programme is intentionally scoped to **the Bytesized box only**. Hetzner Storage Boxes, Netcup VPS workers, seedbox-to-VPS resurrection, and other external infrastructure are future integration points and are **not implementation work in this programme**.

## Current instance

Known from the Bytesized panel and current provider documentation:

- Appbox Lite class;
- 500 GB HDD quota;
- 3 TB monthly outbound/upload allowance;
- 10 Gbit/s shared host connection;
- SSH/FTP access;
- shared public IP;
- managed application platform;
- rootless Docker and Docker Compose support on Appboxes;
- provider reverse proxy capable of giving custom containers HTTPS subdomains;
- no root/sudo access;
- no storage redundancy on Appbox Lite.

These are programme inputs, not performance guarantees. The qualification phase measures what this particular tenant actually receives.

## Intended role

Determine whether the Appbox is useful as a cheap, always-on, limited-privilege node for:

- warm storage and staging;
- Git mirrors/bundles and artifact caches;
- hashing, compression, indexing and file housekeeping;
- scheduled sync and maintenance jobs;
- lightweight persistent Python/container services;
- small orchestration helpers and status/control endpoints;
- future worker bootstrap/cache serving, without implementing any external worker yet.

It is **not** intended to become an authoritative backup, trustworthy performance-reference machine, heavy compute host, VPN/router, or privileged infrastructure node.

## Start here

1. [`docs/RAG_INDEX.md`](docs/RAG_INDEX.md) — retrieval-oriented reference index.
2. [`docs/EXECUTION_PROTOCOL.md`](docs/EXECUTION_PROTOCOL.md) — mandatory issue/PR/check/merge workflow.
3. [`docs/ROADMAP.md`](docs/ROADMAP.md) — programme phases and issue order.
4. [`docs/PLAN_REVIEW.md`](docs/PLAN_REVIEW.md) — review corrections applied before publication.

GitHub issues **#2–#21** are the executable work queue. Each issue is written as an autonomous implementation prompt and is expected to finish through PR, automated checks, evidence reconciliation, and merge.

**Current starting issue:** #3 — `P0-02 Capture tenant environment, quota and capability inventory`.

P0-01 / issue #2 is complete. See [`evidence/P0-01/README.md`](evidence/P0-01/README.md) for the public-safe verification record and [`docs/ACCESS_BOOTSTRAP.md`](docs/ACCESS_BOOTSTRAP.md) for the operational access model.

## Provider references

Current provider behaviour must be rechecked when it matters because managed-hosting features can change:

- Appbox plans: https://bytesized-hosting.com/appbox
- Rootless Docker/custom containers: https://bytesized-hosting.com/guides/run-your-own-docker-containers-on-a-seedbox
- FAQ / quotas / root access / shared IP: https://bytesized-hosting.com/pages/faq
- AI-ready use case: https://bytesized-hosting.com/use-cases/ai-ready-seedbox
