# P1-02 — Rootless Docker / Compose / managed HTTPS qualification

**Current result:** blocked at provider rootless-Docker activation; qualification is intentionally incomplete.

A strictly read-only discovery pass was executed against the real Appbox through the trusted GitHub Actions SSH lane in run `34787462598` on 2026-09-13. No image was pulled, no container was created, no route was exposed, and no existing Docker state was modified.

## Measured tenant state

- Docker CLI is installed: **24.0.2**.
- Docker Compose plugin is installed: **v2.18.1**.
- `DOCKER_HOST` is not set in the noninteractive automation session.
- Docker context is `default`.
- The default endpoint `/var/run/docker.sock` is not usable by the tenant user.
- On this Docker build, formatted `docker info` printed a `permission denied` socket diagnostic while returning process rc **0**; qualification tooling must therefore inspect daemon/socket diagnostics rather than trusting the exit code alone.
- Bytesized's documented per-user rootless endpoint `~/.docker/run/docker.sock` is **absent**.
- Because that provider rootless socket is absent, the per-user Traefik network could not be checked and no container/Compose/HTTPS/persistence/restart test was attempted.

## Provider-supported activation prerequisite

Bytesized's current Docker guide states that if `docker info` cannot reach a daemon, the supported activation route is to install a Docker app from the Bytesized panel once (the guide names Vaultwarden as a small example), or ask Bytesized support to switch Docker on. The same guide documents `~/.docker/run/docker.sock` as the Appbox rootless socket and the `traefik_USERNAME` network as the managed reverse-proxy path for custom containers.

Do **not** work around this by starting an ad-hoc privileged/system Docker daemon, changing host socket permissions, or inventing an unsupported user daemon. The programme should resume P1-02 after the provider-supported rootless service has been activated.

## Next qualification step after activation

Rerun `tools/qualify_docker.sh --phase probe`. Only after it reports the rootless daemon reachable should P1-02 proceed to bounded mutation tests:

1. `hello-world`/equivalent smoke container;
2. minimal Compose smoke test;
3. persistent bind-mount round-trip through container recreation;
4. temporary `restart: unless-stopped` behaviour check;
5. temporary provider-Traefik route with externally verified HTTPS;
6. Docker disk-use measurement and complete cleanup.

Portainer, Docker-socket web exposure, unnecessary raw public ports, privileged networking and large application stacks remain out of scope.

## Tooling correction discovered by the live probe

The first probe exposed a Docker CLI edge case important enough to encode in the reusable tool: a formatted `docker info` can emit a socket permission failure yet return rc 0. The P1-02 qualifier now classifies common daemon/socket diagnostics as unreachable even when the CLI exit status is misleading.

## Cleanup

The trusted execution lane removed its temporary remote task directory and runner-side SSH material. Since the P1-02 pass was read-only, there were no containers, images, volumes, bind-mount test files or public routes to remove.
