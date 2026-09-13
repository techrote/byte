# Scope

## In scope now

This programme may inspect, qualify, configure and automate the existing Bytesized Appbox Lite within the permissions available to the account.

In-scope work includes:

- SSH key-based administration and credential hygiene;
- non-destructive environment/capability inventory;
- quota, filesystem and process-limit inspection;
- bounded HDD and metadata performance tests;
- conservative network qualification within the monthly transfer allowance;
- rootless Docker and Docker Compose validation;
- provider reverse-proxy / HTTPS routing validation;
- restart/persistence behaviour;
- contention/variance sampling over time;
- Git mirrors, bundles and cache/staging layouts;
- artifact manifests, hashing, compression and indexing;
- scheduled jobs and lightweight persistent services;
- disk-space guardrails, log rotation and cleanup;
- portable export/rebuild procedures for Appbox-resident state;
- security hardening possible without root;
- documentation, evidence and operational runbooks.

## Explicitly deferred

The following are future integration points only and must not be provisioned or purchased by issues in this programme:

- Hetzner Storage Box or other offsite backup service;
- Netcup, OVH, AWS, DigitalOcean or any VPS/cloud worker;
- VPS images or worker resurrection pipelines;
- integration with the local i7-6700 machines;
- the second FTTP automation network;
- a dedicated VPN/rendezvous server;
- Git LFS/Codespaces allocation changes;
- migration to a larger Bytesized plan unless a future owner decision changes scope.

Documents may preserve interface requirements that make those future integrations easy, but must not execute them.

## Out of scope by platform design

Do not try to turn the Appbox into something it is not:

- no root/sudo escalation attempts;
- no kernel modules or host firewall control;
- no privileged Docker containers;
- no raw low-port binding workaround intended to evade rootless restrictions;
- no cryptocurrency mining or similar sustained abusive CPU/GPU use;
- no assumption that VPN/network-namespace manipulation is supported;
- no use as an authoritative performance-reference machine;
- no use as the sole copy of irreplaceable data.

## Scope-change rule

If an issue discovers that solving its objective genuinely requires external infrastructure or a forbidden capability, stop that portion of work, document the blocker and propose a separate scope-change issue. Do not silently expand the programme.
