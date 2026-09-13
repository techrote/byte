# Programme verification gates

The programme is complete only when applicable gates below are evidenced on the actual Appbox.

## Access

- Key-based SSH works and host identity verification is documented.
- Repository evidence contains no credentials.
- A recovery path exists if remote automation breaks.
- Repeated SSH sessions remain usable under ordinary load.

## Capability ground truth

- Quota/storage figures are captured from the tenant.
- Shell and process limits are known where observable.
- Scheduling/user-service mechanisms are tested.
- Rootless Docker and Compose capability is proven or ruled out.
- Shared-host resource totals are not represented as tenant entitlement.

## Storage

- Bounded sequential read/write measurements exist.
- Small-file/metadata behaviour is measured.
- Archive/hash/compression representative work is measured.
- Variability is reported across repeated runs.
- Test files are cleaned up and quota guardrails exist.

## Network

- Inbound/outbound accounting behaviour is understood.
- Representative transfer performance is measured conservatively.
- Qualification egress stays within the approved budget.
- Shared-IP/public-service behaviour is understood.

## Containers and application hosting

- Docker smoke testing succeeds.
- Compose or a documented equivalent is usable.
- Persistent data survives container recreation.
- Restart behaviour is tested.
- Provider-managed HTTPS works for a harmless test service.
- Unnecessary public listeners are absent.
- Image/volume storage is included in cleanup planning.

## Useful infrastructure

- The `~/byte` layout is implemented.
- Artifact manifests/checksums work.
- Git mirror/bundle workflow works.
- Health/status reporting works.
- Scheduled maintenance works unattended.
- The box stays responsive during intended workloads.

## Security

- SSH and service exposure follow `SECURITY_MODEL.md`.
- Sensitive public services use application authentication.
- Administrative container interfaces are not exposed publicly.
- Secrets remain outside Git.
- Public services are enumerated and justified.
- No unsupported privileged-networking workaround is introduced.

## Reconstructability

- Relevant configuration exists in Git.
- Mutable state and export paths are documented.
- A portable export bundle is produced.
- Reconstruction into a separate temporary location succeeds and is verified.
- No important programme state depends solely on undocumented manual actions.

## Role envelope

Final documentation classifies candidate tasks as recommended, acceptable with caveats, poor fit, or unsupported, with evidence for each classification.

## Soak gate

During the final soak period:

- expected services remain available or failures are explained;
- disk usage remains bounded;
- cleanup succeeds;
- bandwidth trend is safe;
- logs remain bounded;
- repeated unexplained service crashes do not occur;
- SSH remains responsive.

## Final handover

The final report records the Appbox's useful role, measured characteristics and variance, security/exposure summary, directory/service map, routine maintenance, export/recovery procedure, limitations, and future-integration recommendations without implementing external infrastructure.
