# Agent-to-Appbox access bootstrap

The programme is intended to minimise repeated manual command relay. This document defines acceptable ways to give trusted automation a bounded execution path to the existing Appbox without storing credentials in this public repository.

## Constraint

The connected GitHub integration can edit this repository, issues and Actions metadata, but it does not itself provide a generic SSH terminal into the Bytesized tenant. A one-time access bootstrap is therefore expected before remote implementation issues can become fully autonomous.

## Preferred credential

Use a dedicated Ed25519 SSH key for automation.

- Public key: may be installed in the Appbox account's `~/.ssh/authorized_keys` and may be retained as non-secret metadata if useful.
- Private key: must remain outside repository content/issues/logs.
- Do not reuse the user's general-purpose personal SSH key.
- Record/verify the server host key independently so automation is not trained to accept arbitrary hosts.

## Option A — direct trusted execution environment

If the active agent environment can make outbound SSH connections and can hold the dedicated credential securely for the required session, use direct SSH.

Advantages:

- simplest path;
- low latency;
- easy interactive diagnosis.

Limitations:

- execution environments may be ephemeral;
- a credential stored only in one transient environment is not a durable automation design.

## Option B — GitHub Actions execution lane

A durable option is a deliberately narrow Actions workflow that SSHes to the Appbox and runs versioned repository scripts.

Recommended secret inputs, created by the repository owner through GitHub's secret UI rather than committed:

- `BYTE_SSH_KEY` — dedicated private key;
- `BYTE_HOST` — Appbox hostname if treated as non-public operational configuration;
- `BYTE_USER` — account username if not stored as a repository variable;
- `BYTE_KNOWN_HOSTS` — pinned known-host line/fingerprint material.

Design requirements:

- never use `StrictHostKeyChecking=no`;
- remote commands come from reviewed/versioned scripts rather than arbitrary unlogged strings where practical;
- secrets are not printed;
- fork-originated workflows must not receive credentials;
- keep Actions permissions minimal (`contents: read` unless the job needs more);
- bound remote commands with timeouts;
- collect only redacted evidence;
- the remote account is already unprivileged, but scripts still obey shared-host fair-use policy.

The exact workflow should be implemented by P0-01 after confirming what GitHub secret/environment controls are available.

## User assistance expected once

The likely minimum user contribution is:

1. install the dedicated public SSH key on the Bytesized account, or enable equivalent key authentication;
2. if the Actions lane is chosen, create the required GitHub secrets through the UI;
3. provide/confirm the server host-key fingerprint through a trusted path if it cannot be established independently.

The user should **not** paste the Appbox password, private SSH key or long-lived token into chat or an issue.

## Recovery

Before replacing routine password use, confirm that the Bytesized panel/support path can still recover access if `authorized_keys` is damaged. Do not make the automation channel the only conceivable route to the account.
