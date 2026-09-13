# Agent-to-Appbox access bootstrap

The programme is intended to minimise repeated manual command relay. This document defines the durable execution path from trusted repository branches to the existing Bytesized Appbox without storing credentials in this public repository.

## Implemented credential model

A dedicated Ed25519 key named for the byte automation role is installed in the Appbox account's `~/.ssh/authorized_keys`.

- The public key is installed on the Appbox.
- The private key exists only in the owner's local secure copy and the repository Actions secret `BYTE_SSH_KEY`.
- The user's general-purpose SSH identity is not reused.
- Password authentication remains available through the provider-supported path as recovery rather than being disabled by this programme.

Repository Actions secrets used by the execution lane:

- `BYTE_SSH_KEY` — dedicated private key;
- `BYTE_HOST` — Appbox hostname;
- `BYTE_USER` — Appbox account username;
- `BYTE_KNOWN_HOSTS` — exact pinned known-host entry.

Secret values must never be committed to Git, issues, PR bodies or evidence.

## Verified host identity

The Appbox server ED25519 host key fingerprint was independently observed from the user's local connection and from a GitHub-hosted runner before the automation lane was enabled:

`SHA256:/+RRBhGd7lNUsOiahgXDZc3K7EHCEIrike7ZzLYN8RI`

The Actions lane refuses to run if the fingerprint derived from `BYTE_KNOWN_HOSTS` does not match this value, and SSH itself uses strict host-key checking against the pinned file.

## Durable GitHub Actions execution lane

The canonical `.github/workflows/ci.yml` contains an `appbox-remote` job for trusted issue branches.

Security and execution rules:

1. The job runs only for pull requests whose head repository is this repository and whose branch name begins with `remote/`.
2. Fork-originated pull requests therefore cannot receive the Appbox credentials.
3. Actions permissions remain `contents: read`.
4. Secrets are checked for presence but not printed.
5. The dedicated private key and known-host file exist only in the ephemeral runner and are removed in an `always()` cleanup step.
6. `StrictHostKeyChecking=yes`, `BatchMode=yes` and `IdentitiesOnly=yes` are enforced.
7. The known-host ED25519 fingerprint is verified before connection.
8. Remote task material comes from version-controlled repository files.
9. The task is streamed into an ephemeral remote directory and removed automatically after execution.
10. Remote execution is bounded by workflow and command timeouts.

## Versioned remote task contract

`remote/task.sh` is the fixed execution entrypoint. The default version is read-only and performs a small capability/connectivity smoke test.

For later issues that need Appbox changes:

- create the issue branch with the `remote/` prefix;
- change `remote/task.sh` to the smallest bounded task required by that issue;
- keep any supporting scripts under version control;
- open a PR so the exact task is visible in the diff before it receives credentials;
- let the same-repository PR workflow execute the task and capture public-safe evidence;
- never turn the entrypoint into a general network-exposed command shell.

This is deliberately powerful enough to let trusted repository issue branches perform autonomous implementation while keeping the credential boundary auditable in Git history and Actions logs.

## Recovery

The automation channel is not the only conceivable access path. The owner retains ordinary provider-supported account access, including the Bytesized control-panel/password/support recovery route. If the dedicated key is compromised or misconfigured, remove its public key from `authorized_keys`, rotate/delete `BYTE_SSH_KEY`, and create a new dedicated automation identity before resuming remote work.
