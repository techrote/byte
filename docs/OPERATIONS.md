# Operations model

This document defines the intended operating shape once qualification confirms the relevant platform capabilities.

## Proposed home-directory layout

Use an explicit hierarchy under the user's home directory rather than scattering state:

```text
~/byte/
  apps/          # Compose projects and persistent app data
  bin/           # user-installed scripts/binaries
  cache/         # disposable warm caches
  git/           # mirrors/bundles
  artifacts/     # staged outputs with manifests/checksums
  manifests/     # indexes and inventories
  jobs/          # bounded job inputs/state
  logs/          # programme-owned logs
  tmp/           # disposable working data
  exports/       # portable reconstruction/export bundles
```

Adapt only if provider-managed conventions require another path. Do not move managed Bytesized app data without understanding provider expectations.

## Capacity policy

The 500 GB quota is small enough that unattended jobs need explicit guardrails.

Initial policy target, to be adjusted after measurement:

- warning at 70% quota;
- strong warning / cleanup at 80%;
- block non-essential staging at 90%;
- retain at least 10% or 25 GB free, whichever is larger, unless an issue explicitly justifies otherwise.

`quota` should be treated as the immediate authoritative view where available. Panel values may lag.

## Data classes

### Reconstructable

May be aggressively pruned:

- package/download caches;
- Docker image layers not required by running services;
- generated build artifacts that exist elsewhere;
- temporary test data;
- cloned working trees that can be recreated.

### Operational state

Must be exported/reconstructable before deletion:

- service configuration;
- manifests/indexes;
- job metadata;
- Git bundles/mirrors not trivially reproducible from public upstreams;
- persistent container data.

### Important data

Must never exist only on the Appbox. Until external backup is added in a future programme, maintain another copy elsewhere before classifying anything as important.

## Logging

Programme-owned services should:

- log to `~/byte/logs/<service>/` or a documented container bind mount;
- rotate by size/time;
- avoid secrets in logs;
- retain enough recent history to diagnose restarts and contention;
- provide concise health output separate from verbose logs.

## Scheduling and service supervision

P1-01 and P1-02 establish the current user-level operating model:

1. **Cron is canonical for simple periodic maintenance/scheduled jobs.** A temporary crontab entry executed successfully on the real tenant and the prior crontab was restored afterward.
2. **`nohup` is acceptable for bounded one-off jobs that must survive an SSH disconnect.** It is not a persistent service manager; jobs need explicit log/output paths and cleanup semantics.
3. **`tmux` and `screen` are optional interactive/resumable tools.** Both are already installed and proved able to execute detached commands, but automation should not depend on interactive session semantics when cron or a proper application lifecycle is more appropriate.
4. **Do not depend on `systemd --user`.** The noninteractive tenant session did not expose a usable user DBus/XDG runtime environment.
5. **Rootless Docker/Compose is the preferred lifecycle for suitable persistent custom services.** P1-02 proved Compose startup, bind-mounted persistence, `restart: unless-stopped`, safe container restart and provider-managed HTTPS on the actual tenant.

For cron-managed scripts:

- use absolute command/script paths;
- explicitly set any required `PATH` or environment in the script rather than assuming an interactive shell;
- redirect bounded logs to `~/byte/logs/<job>/` once the operational layout exists;
- make jobs idempotent where practical and safe under delayed/duplicate invocation;
- use lock files or equivalent when overlapping runs would be unsafe;
- retain a cleanup path and avoid writing secrets into cron lines or logs.

For programme-managed containers:

- in noninteractive automation explicitly set `DOCKER_HOST=unix://$HOME/.docker/run/docker.sock`;
- keep Compose projects and persistent bind-mounted state in explicit programme-owned directories, eventually under `~/byte/apps/<service>/` once the layout phase creates it;
- prefer the provider `traefik_${USER}` network and managed HTTPS for justified web exposure rather than publishing raw host ports;
- use application authentication/authorization for sensitive public services;
- use `restart: unless-stopped` for suitable long-lived services;
- do not treat Docker CPU/RAM limits or host totals as enforceable tenant allocation because the measured rootless daemon runs without cgroups;
- never make broad cleanup commands responsible for provider-managed one-click applications; delete only exact programme-owned resources;
- pin versions/digests for important long-lived services where practical.

Do not build an elaborate shell supervisor when cron covers periodic work and the qualified container lifecycle covers persistent services.

## Update policy

- Pin versions for important long-lived utility services where practical.
- Update intentionally, not automatically to arbitrary latest images without a rollback path.
- Record current image tags/digests and configuration in Git.
- Back up/export service state before schema-changing upgrades.

## Health checks

A lightweight health command/report should eventually cover:

- quota used/free;
- size of major `~/byte` directories;
- running expected containers/services;
- failed/restarting containers;
- recent job failures;
- stale manifests/exports;
- monthly outbound usage where provider data is accessible;
- last successful maintenance/cleanup run.

## Recovery principle

Configuration belongs in Git; mutable state must be exportable; caches are disposable. A fresh Appbox account should be reconstructable without undocumented shell history.
