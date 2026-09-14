# Decision log

This file records durable programme decisions. Issues may amend decisions when new evidence justifies it.

## D-001 — Current programme is Bytesized-only

**Status:** accepted

The current programme qualifies and develops the existing Bytesized Appbox only. External backup/storage providers, VPSs, local compute workers and second-FTTP integration are deferred.

**Reason:** isolate variables, learn the actual value of the €5 Appbox first, and avoid designing around infrastructure that does not yet exist.

## D-002 — Treat Appbox storage as warm/non-authoritative

**Status:** accepted

The Appbox may hold caches, staging data, mirrors, manifests and operational state, but must not become the sole copy of irreplaceable data.

**Reason:** current plan documentation states there is no disk redundancy.

## D-003 — Rootless Docker is the preferred packaging mechanism for persistent custom services

**Status:** accepted and validated by P1-02

Use rootless Docker/Compose for suitable custom services. P1-02 proved the actual tenant's per-user daemon at `~/.docker/run/docker.sock`, Compose startup, bind-mounted persistence, `restart: unless-stopped`, safe restart behaviour and provider-managed HTTPS.

Noninteractive automation should explicitly set `DOCKER_HOST=unix://$HOME/.docker/run/docker.sock`. Do not interpret containerisation as privileged isolation or Docker CPU/RAM figures as enforceable tenant quotas; the measured rootless daemon reports that cgroups are unavailable in this environment.

**Reason:** provider support is now backed by live tenant evidence, while the provider's documented resource/isolation limitations were also observed directly.

## D-004 — Performance work measures useful-task variance, not entitlement

**Status:** accepted

Shared-host performance will be characterised with bounded representative tasks across multiple time windows. Host-reported CPU/RAM totals do not establish allocation.

## D-005 — Do not install Portainer by default

**Status:** accepted

Portainer is convenient but requires access to the rootless Docker socket, creating another sensitive administrative web surface. Use CLI/Compose initially. Revisit only if operational complexity justifies it.

## D-006 — Public services use managed HTTPS and application authentication

**Status:** accepted and HTTPS path validated by P1-02

When public reachability is needed, prefer Bytesized's documented reverse-proxy/HTTPS path. P1-02 proved an exact temporary custom container could join `traefik_${USER}` and return HTTP 200 with successful TLS verification from an external GitHub-hosted runner without publishing a raw host port.

TLS alone is not authorization; sensitive services require application-level authentication.

## D-007 — No VPN/router role

**Status:** accepted for current scope

Do not attempt to make the Appbox the trusted WireGuard/VPN/router layer. Provider documentation describes VPN-style containers as untested, and the account lacks root/network control.

## D-008 — Remote execution bootstrap should minimise recurring user terminal work

**Status:** accepted and implemented

Use a dedicated Ed25519 automation identity, strict pinned host verification and a narrow GitHub Actions execution lane for bounded version-controlled Appbox tasks. Authentication material remains outside Git.

The initial live probe proved non-interactive execution on the actual tenant. Current connected-agent safety controls may still require an explicit owner trigger for a credential-bearing workflow run; that is preferable to bypassing the guardrail and is not a reason to weaken host verification or credential isolation.

## D-009 — Default outbound qualification budget is 50 GB

**Status:** accepted

Do not consume more than 50 GB of the 3 TB monthly outbound quota on qualification unless an issue explicitly revises the allowance.

## D-010 — External backup is expected later but not implemented now

**Status:** deferred

This programme must still prove portable export/reconstruction locally so a future backup service can ingest a known-good format rather than becoming the first time recovery is tested.

## D-011 — Cron is the canonical periodic scheduler; detached shells are bounded one-offs only

**Status:** accepted from P1-01 evidence, extended by P1-02

Use user crontab as the canonical mechanism for simple periodic maintenance and scheduled jobs. P1-01 installed a temporary minutely entry, observed it execute, and restored the prior crontab without requiring root privileges.

`systemd --user` is not a current dependency: the noninteractive Appbox session had no usable user DBus/XDG runtime environment, so a transient user unit could not be started.

`tmux` and `screen` are both available and proved able to run detached commands, but they are interactive/resumable session tools rather than the canonical unattended scheduler. `nohup` also proved that a bounded process can survive SSH disconnect; use it only for simple one-off work with explicit logs/cleanup, not as a substitute for a service manager.

Persistent application supervision remains separate from periodic scheduling. P1-02 proved the rootless Docker/Compose lifecycle and `restart: unless-stopped`, so suitable long-lived custom services should use the provider container lifecycle instead of an improvised shell supervisor.
