# P0-02 tenant capability inventory

Result: pass with follow-up unknowns.

Observation time: 2026-09-13T22:10:24Z. Source: read-only Appbox inventory run `34785970557`. No software was installed, no configuration was changed, and no benchmark or transfer test was performed.

## Tenant-visible platform

- Ubuntu 22.04.5 LTS, Linux 5.15.0-186-generic x86_64.
- Bash 5.1.16; glibc 2.35.
- Home layout matches `/home/<provider-segment>/<account>`; identifiers are omitted.
- Filesystem is ext4.
- Tenant quota at observation time: 10,598M used, 477G soft quota, 525G hard limit.
- Shared backing mount reported about 5.5T total, 3.0T used and 2.5T free. This is host-reported shared storage, not tenant entitlement; `quota` is the capacity boundary to use operationally.
- Open-file limit: 65,536. Core dumps disabled. Stack limit: 8 MiB.

## Installed tools

Present: Git 2.34.1, Python 3.10.12, pip 22.0.2, rsync 3.2.7, rclone 1.62.2, tar 1.34, gzip 1.10, zstd 1.4.8, xz 5.2.5, zip/unzip/7z, checksum utilities, OpenSSL 3.0.2, curl 7.81.0, Wget 1.21.2, SQLite 3.37.2, GCC/G++ 11.4.0, Make 4.3, CMake 3.22.1, Node.js 24.21.0, npm 11.19.0, FFmpeg 4.4.2, cron/crontab, systemctl, Docker client 24.0.2 and Docker Compose v2.18.1.

Missing from PATH: `jq`, Go, `rustc`, and `cargo`.

The pip wrapper emitted an age/deprecation warning; later scripts should prefer `python3 -m pip`.

## Scheduler and service observations

- cron/crontab commands are present.
- No existing crontab was observed by the non-content-reading check.
- `systemctl --user` did not have a usable user-session bus in the noninteractive probe. This does not prove that user-systemd is unavailable in every provider session; P1-01 must test it deliberately.

## Docker observation

- Docker client and Compose are installed.
- The default Docker context did not have an accessible daemon for this probe.
- Rootless Docker therefore remains an explicit P1-02 qualification item rather than an assumed working capability.

## Safe directory observations

`~/www` and `~/.config` were present. `~/.local` and `~/.docker` were absent. Presence alone does not establish provider ownership or semantics.

## Host-reported shared resources

The account can see 48 logical CPUs on a dual-socket Intel Xeon E5-2650 v4 host and about 251 GiB RAM. These figures describe the shared host view only and are not tenant CPU/RAM allocation.

## Conclusions

The existing user-space toolchain is already sufficient for the planned Git, archive, checksum, sync, Python, Node, SQLite and small native-build workflows. Cron is the strongest currently observed scheduler candidate. Docker and user-systemd require their dedicated later qualification issues. Storage automation must use the tenant quota rather than shared-mount free space.

No persistent test data or service was created by this issue.
