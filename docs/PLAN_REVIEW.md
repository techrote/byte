# Plan review and corrections

This document records the review performed before issue publication.

## Initial direction

The initial direction was to connect by SSH, test the platform, install useful lightweight services, and eventually use the Appbox as a warm staging and utility tier.

That direction remains, with the following corrections.

## Corrections applied

### External infrastructure removed from current scope

Only the Bytesized box is implemented now. Hetzner, Netcup, local worker machines and other future resources are interface considerations only.

### Access bootstrap precedes qualification

A repeatable key-based administration path is established before deeper testing so later work does not depend on repeated manual password use.

### Provider specifications are separated from measurements

Advertised connection speed, shared-host CPU/RAM visibility, transcode counts and container resource displays are not treated as tenant performance guarantees.

### Benchmarking is reframed as bounded qualification

The programme uses representative file, metadata, hashing, compression, Git and container tasks rather than long synthetic saturation.

### Network qualification has a fixed default budget

The initial qualification programme may use no more than 50 GB of outbound traffic without an explicit decision to raise the allowance.

### Rootless Docker is packaging, not an entitlement boundary

The plan does not depend on container CPU/RAM flags, GPU access, privileged networking or host totals because provider documentation warns those assumptions are invalid on this platform.

### Public HTTPS is not treated as authorization

Provider-managed TLS is useful, but sensitive applications still require their own authentication and deliberately limited exposure.

### Portainer is deferred

CLI and Compose remain the initial management route. A Docker administration web UI is added only if later evidence shows enough operational value to justify another management surface.

### Disk durability is treated explicitly

Appbox data is warm/reconstructable state unless another copy exists because the current plan is documented without storage redundancy.

### Reconstruction is tested before any future external backup integration

A portable export and local reconstruction rehearsal are part of this programme so later backup integration receives a proven format.

### Contention is sampled over time

A low-impact 24–48 hour sampling phase is separated from one-time throughput measurements because consistency matters for unattended utility work.

### Useful infrastructure comes before generic orchestration

Artifact staging, Git caching, health reporting and maintenance are implemented before a generic job helper. The box should be useful even if more ambitious orchestration is never needed.

## Unknowns intentionally left unresolved

Issues must determine rather than guess:

- exact shell/runtime/tool availability;
- whether user-level service management is persistent;
- current Docker initialization state;
- actual filesystem/HDD behaviour and contention;
- practical ingress/egress rates;
- provider maintenance/restart behaviour;
- whether useful official automation hooks exist;
- the best agent-to-Appbox execution transport.

## Conclusion

The revised plan is conservative around access and data safety, but empirical around platform capability. It should establish the real value of the €5 Appbox before any wider infrastructure commitment.
