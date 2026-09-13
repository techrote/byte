# P0-01 evidence

Result: pass.

A dedicated Ed25519 automation identity was installed on the Appbox and exercised non-interactively from GitHub Actions. The lane enforces strict known-host checking against the independently verified server ED25519 fingerprint and verifies the client-key fingerprint before connection.

Successful verification used GitHub Actions run 34784892329. The final rerun completed both repository validation and `appbox-remote-smoke` successfully. The remote task reported `remote_exec=ok` and `remote_probe=complete`, then the runner removed ephemeral SSH material.

Observed during the read-only smoke test: Linux 5.15.0-186-generic x86_64; quota command available; git, Python 3, rsync, rclone, tar, gzip, zstd, sha256sum, curl, cron/crontab, systemctl and Docker client present; Docker Compose v2.18.1 present. The Docker server was unavailable to the smoke command and requires dedicated qualification before interpretation.

The host-visible home filesystem was approximately 5.5 TB total with 2.5 TB available at the observation time. This is host-reported shared storage information, not evidence of the tenant's quota or entitlement.

No credential value is stored in this evidence. Password/control-panel recovery remains available independently of the automation key.
