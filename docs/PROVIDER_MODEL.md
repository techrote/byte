# Bytesized provider model

This document records current provider claims and the operational consequences relevant to the programme. It is not a substitute for measurement on the actual tenant.

Last researched: 2026-09-13.

## Current plan model

Bytesized currently advertises Appbox Lite at €5/month with:

- 500 GB HDD storage;
- 3 TB monthly upload/outbound allowance;
- 10 Gbit shared connection;
- unlimited inbound/download traffic;
- no storage redundancy;
- managed application platform.

Source: https://bytesized-hosting.com/appbox

## Shell and privilege model

Provider FAQ and guides currently state:

- Appboxes provide SSH access;
- there is no root access on Appboxes;
- managed Appboxes use a shared public IP;
- `quota` is the authoritative immediate quota view; the web panel may update periodically;
- all server-generated outbound/upload traffic counts against the bandwidth allowance;
- inbound/download traffic does not count against that allowance.

Source: https://bytesized-hosting.com/pages/faq

Operational consequence: treat the account as a capable unprivileged Unix user, not as a VPS administrator.

## Rootless Docker model

Bytesized currently documents rootless Docker and SSH as supported on every Appbox. Custom Docker/Compose workloads can join the provider's per-user Traefik network and receive automatic HTTPS subdomains.

Important documented constraints:

- no GPU access inside custom containers;
- direct privileged ports below 1024 are unavailable under rootless Docker;
- custom web apps normally should use the provider reverse proxy rather than public raw ports;
- Docker `--memory` and `--cpus` flags are accepted but not enforced in this setup;
- `docker stats` and similar resource totals can reflect host resources rather than the tenant's effective share;
- VPN-style containers that manipulate networking are described as untested territory;
- Docker images count against the user's disk quota;
- restart policies such as `unless-stopped` are expected to restore containers after host reboot.

Source: https://bytesized-hosting.com/guides/run-your-own-docker-containers-on-a-seedbox

### Measured tenant confirmation — P1-02

The first live probe found the client and Compose plugin installed but the documented per-user daemon socket absent. Installing a Docker-backed app from the Bytesized panel using the provider-supported path initialized the tenant's rootless Docker environment.

After activation, the actual tenant measured:

- Docker server/client **24.0.2** and Compose **v2.18.1**;
- reachable rootless daemon at `~/.docker/run/docker.sock`;
- Docker security options containing `rootless`;
- provider network `traefik_${USER}` present;
- ordinary `/var/run/docker.sock` still inaccessible to the tenant;
- Compose startup and bind-mounted persistence working;
- `restart: unless-stopped` present and a safe container restart preserving service data;
- temporary custom web container reachable externally through provider-managed HTTPS with successful TLS verification and no raw published port;
- exact qualification cleanup returning Docker to its pre-test post-activation footprint.

Noninteractive sessions did not automatically select the per-user socket, so programme automation should explicitly use `DOCKER_HOST=unix://$HOME/.docker/run/docker.sock`.

The rootless daemon also emitted a warning that it is running **without cgroups**, directly reinforcing the provider warning that Docker CPU/RAM controls are not a tenant-resource entitlement mechanism here.

Operational consequence: containerisation is qualified and useful for packaging/persistent services, but not a reliable resource-isolation or performance-entitlement mechanism on this platform.

## Fair-use / contention model

The FAQ explicitly describes CPU as a shared valuable resource and applies limits so one customer cannot degrade the host. It prohibits mining because it interferes with other users.

Source: https://bytesized-hosting.com/pages/faq

Programme interpretation:

- expect contention and time-varying CPU/I/O performance;
- characterise variance rather than chase a peak benchmark;
- favour I/O-bound, bursty and latency-tolerant utility work;
- do not run indefinite synthetic CPU saturation;
- use representative bounded workloads and terminate tests when the question is answered.

## Durability model

Current Appbox plan tables explicitly show `No redundancy` for Appbox Lite.

Programme interpretation:

- data on the box is operational state/cache/staging unless another copy exists;
- important data must remain exportable;
- future offsite backup integration is expected but explicitly deferred from this programme;
- local restore/reconstruction drills are still required so later backup integration has a proven target format.

## Marketing metrics that are not guarantees

Do not treat these as tenant performance guarantees:

- 10 Gbit connection;
- apparent CPU count from host commands;
- host RAM totals;
- Docker resource totals;
- number of advertised transcodes as an exact CPU entitlement.

Measured task completion time and variance are more useful programme evidence.
