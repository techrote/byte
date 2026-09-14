# P1-02 — Rootless Docker / Compose / managed HTTPS qualification

**Result: PASS.** The actual Appbox rootless-Docker path, Compose persistence, restart behaviour and provider-managed HTTPS were qualified end to end, and all programme-created test resources were removed afterward.

## Activation history

The initial read-only probe, GitHub Actions run `34787526206`, found Docker 24.0.2 and Compose v2.18.1 installed but Bytesized's documented per-user socket `~/.docker/run/docker.sock` absent. The default `/var/run/docker.sock` was not usable by the tenant account. The qualifier also discovered that this Docker CLI can print a socket permission failure while a formatted `docker info` exits with rc 0, so the tool was corrected to classify common daemon/socket diagnostics semantically rather than trusting exit status alone.

The user then performed the least-invasive provider-supported activation action by installing the Bytesized Docker-backed **Wsrelay** application from the panel. No host-level workaround, socket-permission change or ad-hoc daemon was used.

Post-activation run `34790869874` at `2026-09-13T23:51:10Z` confirmed:

- `~/.docker/run/docker.sock` exists as a Unix socket;
- explicit `DOCKER_HOST=unix://$HOME/.docker/run/docker.sock` reaches Docker server **24.0.2**;
- Docker security options include `rootless` and `cgroupns`;
- Compose **v2.18.1** is available;
- the provider network `traefik_${USER}` exists;
- the ordinary default endpoint `/var/run/docker.sock` remains inaccessible, as expected for this tenant;
- baseline Docker state after provider activation was **3 images / 2 active containers / 331.6 MB** of images.

For noninteractive programme automation, explicitly select the per-user rootless socket instead of assuming the default Docker endpoint.

## Canonical bounded runtime qualification

The canonical mutation pass was GitHub Actions run `34791197678` from remote execution commit `c6c5f7409062eacc7b749dd0fef5a91640ab8655`, with the remote qualification beginning at `2026-09-13T23:58:30Z`.

All temporary resources used an exact `byte-p1-02-*` namespace. No privileged container, Docker-socket exposure, raw public port, VPN/network manipulation or large application stack was used.

Measured results:

- small `alpine:3.20` smoke container: **pass**;
- Compose configuration parse and startup: **pass**;
- host bind-mounted token readable inside the first container: **pass**;
- bind-mounted token survived complete container removal and recreation: **pass**;
- configured restart policy observed as `unless-stopped`: **pass**;
- data remained readable after a safe `docker restart`: **pass**;
- temporary web container joined the provider `traefik_${USER}` network: **pass**;
- no host port was published for the web container: by design;
- provider-managed route was generated from the existing tenant routing convention without storing the private tenant hostname in repository evidence.

The rootless daemon emitted `Running in rootless-mode without cgroups. Systemd is required to enable cgroups in rootless-mode.` This agrees with provider guidance that Docker CPU/RAM flags on this platform must not be treated as enforceable tenant allocation.

## External managed-HTTPS proof

The temporary `traefik/whoami` service was reached from the GitHub-hosted Actions runner, not from the Appbox itself. The generated URL was masked in Actions logs and is intentionally not stored in repository evidence.

The first external attempt succeeded with:

- HTTP status: **200**;
- TLS verification result: **0** (certificate/hostname verification successful);
- TCP connect: **0.148846 s**;
- TLS handshake: **0.257648 s**;
- total request time: **0.390254 s**;
- response body: non-empty.

This proves the actual tenant's custom-container path through the provider reverse proxy and automatic HTTPS without publishing a raw service port.

## Disk impact

The true post-Wsrelay baseline before any P1-02 image pull was:

- 3 images;
- 2 active containers;
- 331.6 MB image footprint.

At the runtime-test peak:

- 5 images;
- 4 active containers;
- 352.3 MB image footprint.

The temporary image-footprint increase was approximately **20.7 MB**. No Docker volumes were created; persistence was tested with an ordinary bind mount.

## Cleanup and preliminary-run note

An earlier preliminary mutation run `34791166337` stopped after the initial bind-mount check because `docker compose rm` encountered a transient `removal ... is already in progress` race. That run had already proved the smoke container, route-host discovery, Compose parsing and first bind read. The canonical run repeated the path successfully and completed all acceptance tests, so the preliminary failure is classified as a test-orchestration/runtime race rather than a provider limitation.

Canonical cleanup removed the temporary route, containers, Compose network, bind-mounted test directory and the newly pulled `traefik/whoami` image. Because the preliminary run had left `alpine:3.20` cached, a final exact-scope cleanup run `34791295742` removed that remaining issue-owned image and verified:

- temporary containers absent;
- temporary Compose network absent;
- temporary bind data absent;
- final Docker state **3 images / 2 active containers / 331.6 MB**, exactly matching the pre-test post-Wsrelay baseline;
- provider-managed/Wsrelay containers were left untouched.

P1-02 therefore satisfies all acceptance criteria for rootless Docker, Compose, bind persistence, restart behaviour, managed HTTPS, disk-impact measurement and cleanup.
