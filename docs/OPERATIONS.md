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

Preferred order after capability testing:

1. rootless Docker restart policies for containerised services;
2. `systemd --user` if provider-supported and persistent;
3. cron for simple periodic jobs;
4. provider-managed application lifecycle where it better fits the service.

Do not build an elaborate supervisor until tests establish what survives host maintenance/reboot.

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
