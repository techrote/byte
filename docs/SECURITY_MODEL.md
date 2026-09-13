# Security model

The repository is public. The Appbox is a shared managed host with no root privilege. Security therefore depends on strict credential hygiene, conservative service exposure, and treating the provider boundary as outside our trust domain.

## Assets

Protect:

- SSH account access;
- Bytesized panel credentials/session cookies;
- application credentials;
- GitHub tokens/keys;
- future API/webhook secrets;
- private repository credentials if ever used;
- any non-public artifacts placed on the Appbox.

## Trust boundaries

1. **Public GitHub repository** — contains only non-secret configuration, scripts, evidence and documentation.
2. **Bytesized account** — unprivileged tenant on shared infrastructure; provider administrators and host platform remain outside our control.
3. **Rootless Docker namespace** — packaging boundary, not a strong resource or provider trust boundary.
4. **Provider reverse proxy / shared public IP** — public ingress controlled partly by Bytesized infrastructure.
5. **User workstation** — initially the trusted administrative origin for bootstrapping access.

## Credential rules

- Never commit SSH private keys, passwords, tokens, cookies, application secrets, `.env` files containing secrets, or provider config exports that contain credentials.
- Prefer a dedicated Ed25519 SSH key for this Appbox rather than password automation.
- The public key may be documented; the private key must remain outside Git.
- Once key login is proven, reduce routine password use. Do not disable a provider-supported recovery mechanism without an alternative.
- Where GitHub Actions is later used as an execution transport, secrets must live in GitHub Secrets/Environment Secrets, not workflow YAML or issue text.
- Do not paste long-lived secrets into issue comments, PRs, CI logs or evidence files.

## SSH administration

Initial work should establish:

- host-key fingerprint verification;
- dedicated key-based authentication;
- restrictive permissions on `~/.ssh` and `authorized_keys`;
- an inventory of supported SSH ciphers/auth methods only if relevant to a concrete issue;
- an explicit recovery route through the Bytesized panel/support if SSH configuration is broken.

Because the user cannot control `sshd_config`, host-level hardening options that require root are not programme responsibilities.

## Public services

Default rule: **do not expose a service unless its public reachability provides value**.

When a web service is required:

- prefer the documented Bytesized Traefik/HTTPS path;
- do not publish a raw port to `0.0.0.0` merely because it works;
- require application authentication for sensitive data/actions;
- avoid exposing debug endpoints, Docker sockets, internal metrics, filesystem browsers, or admin interfaces without explicit authentication;
- document the exact hostname and purpose without committing credentials.

The presence of HTTPS proves transport encryption, not authorization.

## Docker-specific rules

- Never mount the rootless Docker socket into an Internet-facing container unless the risk is explicitly justified; control of that socket effectively grants control over the user's containers and mounted data.
- Pin or at least record image versions/digests for long-lived services when practical.
- Avoid `latest` for important unattended services unless the update policy intentionally tracks it.
- Bind persistent data under a documented home-directory layout rather than relying on anonymous volumes.
- Treat resource flags as advisory/non-functional on this platform per provider documentation.

## Shared-host assumptions

Do not store anything on the Appbox that would be catastrophic if the provider, host, or tenant account were compromised. Encrypt sensitive archives client-side where that materially reduces risk.

## CI/remote execution safety

If an automated GitHub-to-Appbox SSH path is implemented:

- it must run only trusted repository code;
- fork PRs must never receive Appbox credentials;
- known-host verification is mandatory;
- the remote account remains unprivileged;
- CI must not echo secret values;
- remote scripts must be bounded and auditable in this repository.

A remote-execution channel is an operational convenience, not permission to bypass the programme's scope or fair-use limits.
