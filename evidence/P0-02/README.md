# P0-02 tenant inventory evidence

**Result:** pass with follow-up unknowns.

**Observation time:** 2026-09-13T22:10:24Z. The inventory was read-only: no software installation, configuration change, benchmark data or transfer test was performed.

## Tenant-visible platform

- Ubuntu 22.04.5 LTS; Linux 5.15.0-186-generic x86_64.
- Bash 5.1.16; glibc 2.35.
- Home layout follows the provider's two-level `/home/<segment>/<account>` convention; identifiers are omitted.
- Home storage is ext4.
- Quota at observation: 10,598M used, 477G soft quota, 525G hard limit.
- The shared backing mount showed about 5.5T total and 2.5T free. This is host-reported shared storage, not tenant entitlement; operational capacity decisions must use `quota`.
- Open-file limit: 65,536; core dumps disabled; stack limit: 8 MiB.

## Installed tools

Observed present: Git 2.34.1, Python 3.10.12, pip 22.0.2, rsync 3.2.7, rclone 1.62.2, tar 1.34, gzip 1.10, zstd 1.4.8, xz 5.2.5, zip/unzip/7z, checksum utilities, OpenSSL 3.0.2, curl 7.81.0, Wget 1.21.2, SQLite 3.37.2, GCC/G++ 11.4.0, Make 4.3, CMake 3.22.1, Node.js 24.21.0, npm 11.19.0, FFmpeg 4.4.2, cron/crontab, systemctl, Docker client 24.0.2 and Docker Compose v2.18.1.

Missing from PATH: `jq`, Go, `rustc`, and `cargo`.

The pip wrapper emitted a deprecation warning; later scripts should prefer `python3 -m pip`.

## Scheduling and services

Cron/crontab commands are present. No existing crontab was observed by the non-content-reading check. A user-systemd bus was not available in the noninteractive inventory session; this remains a P1-01 qualification question rather than a conclusion that user-systemd is universally unavailable.

Docker client and Compose are installed, but the default context did not expose an accessible daemon in this probe. Rootless Docker remains a P1-02 qualification item.

## Safe directory observations

`~/www` and `~/.config` were present. `~/.local` and `~/.docker` were absent. Presence alone does not establish provider ownership or semantics.

## Host-reported shared resources

The shared host view exposed 48 logical CPUs on a dual-socket Intel Xeon E5-2650 v4 system and about 251 GiB RAM. These values are descriptive host observations only and are **not** tenant CPU/RAM allocation.

## Conclusion

The existing user-space toolchain is already sufficient for the planned Git, archive, checksum, sync, Python, Node, SQLite and small native-build workflows. Cron is the strongest currently observed scheduler candidate. Storage automation must use tenant quota rather than backing-mount free space. Docker and user-systemd need their dedicated later qualification issues.

No persistent test data or service was created.
