# P1-01 — SSH, session, scheduling and user-service qualification

**Result:** pass with explicit service-supervision limitation.

The exact qualifier revision from commit `1b1d53f994c534374474f5af73c8b85d94984711` was exercised through separate authenticated SSH executions on the real Appbox. No package installation or sustained resource load was used.

## Remote execution and setup consistency

Three controlled GitHub-runner-to-Appbox executions completed successfully:

| Phase | Actions run | Execute-step start → first remote output | Result |
|---|---:|---:|---|
| active | `34786910210` | 1.384 s | pass |
| verify | `34787023789` | 1.564 s | pass |
| ping | `34787063574` | 3.516 s | pass |

Median observed transport/task-start latency: **1.564 s**; range **1.384–3.516 s**.

This timing includes the GitHub runner invoking the tar/SSH transport plus remote temporary-directory/task startup until the first `remote_exec=ok` output. It is **not** a pure TCP/SSH handshake benchmark and the three observations are only a small reliability sample.

The three active-phase login-shell samples were consistent: `/bin/bash` with umask `0022`. The final read-only ping also observed `/bin/bash`, umask `0022`.

## Background responsiveness

While a five-second background sleeper was alive, a foreground login-shell no-op completed successfully: `background_responsiveness=pass`. This is a functional concurrency check only, not a performance benchmark.

## Cron

A temporary user crontab entry was installed, wrote its expected marker, and the test reported `cron_test=pass`. The qualifier then restored the previous crontab state before proceeding.

Conclusion: **user cron is the canonical choice for simple periodic Appbox maintenance/jobs**. Scripts should use explicit paths/environment, bounded logs and overlap protection where needed.

## User systemd

`systemctl --user is-system-running` returned rc 1 with:

`Failed to connect to bus: $DBUS_SESSION_BUS_ADDRESS and $XDG_RUNTIME_DIR not defined ...`

A transient user unit was therefore unavailable. Do not make `systemd --user` a programme dependency in the current Appbox execution environment.

## Existing detached-session tools

Both already-installed tools worked without installation:

- `tmux_test=pass`;
- `screen_test=pass`.

They are useful for interactive/resumable sessions, but cron is a better canonical mechanism for unattended periodic work.

## Disconnect persistence

The active SSH execution launched a `nohup` process and disconnected at approximately `22:29:49Z`. That process wrote its marker at `22:29:54Z`, after the originating SSH session had ended. A completely separate SSH execution at `22:31:06Z` reported:

`disconnect_persistence=pass marker=nohup-ok 2026-09-13T22:29:54Z`

This proves a simple detached user process can survive SSH disconnect. `nohup` remains appropriate only for bounded one-off jobs, not as a durable service manager.

## Cleanup

The verification phase removed `~/.byte-p1-01-test` and reported `cleanup=pass`. The active phase explicitly terminated its temporary tmux/screen sessions and restored the prior crontab state. The existing GitHub remote lane separately removed its temporary remote task directory and runner-side SSH material.

## Operational decision

- periodic maintenance: **cron**;
- bounded disconnected one-off process: **nohup** when appropriate;
- interactive resumable work: **tmux/screen**, optional;
- `systemd --user`: **not relied upon**;
- persistent application/service lifecycle: defer to P1-02 rootless-Docker/provider qualification rather than inventing a shell supervisor.
