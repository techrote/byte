#!/usr/bin/env bash
set -euo pipefail

# Read-only live health snapshot. No service, scheduler, container, or file is modified.
export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
state="$HOME/.byte-p1-05"

echo 'remote_exec=ok'
printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'uptime='; uptime -p || true
printf 'loadavg='; cat /proc/loadavg 2>/dev/null || true

# User-owned process RSS only; host MemTotal is not tenant entitlement.
ps -u "$(id -u)" -o rss= 2>/dev/null | awk '{s+=$1} END {printf "user_process_rss_mib=%.1f\n", s/1024}'
printf 'user_process_count='; ps -u "$(id -u)" -o pid= 2>/dev/null | wc -l | tr -d ' '

if command -v quota >/dev/null 2>&1; then
  quota -w -v 2>/dev/null | awk '$2 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ && $4 > 0 {printf "quota_used_kib=%s\nquota_soft_kib=%s\nquota_hard_kib=%s\n",$2,$3,$4; exit}' || true
fi

df -Pk "$HOME" 2>/dev/null | awk 'NR==2 {printf "fs_used_kib=%s\nfs_available_kib=%s\nfs_use_percent=%s\n",$3,$4,$5}' || true

if docker info >/dev/null 2>&1; then
  echo 'docker_reachable=yes'
  docker ps --format 'container={{.Names}};status={{.Status}};image={{.Image}}'
  printf 'docker_running='; docker ps -q | wc -l | tr -d ' '
else
  echo 'docker_reachable=no'
fi

if [[ -f "$state/window.env" ]]; then
  echo 'sampler_window_begin'
  sed -n -E 's/^(START_UTC|END_UTC|DURATION_HOURS|INTERVAL_MINUTES)=/\L\1=/p' "$state/window.env" 2>/dev/null || cat "$state/window.env" 2>/dev/null || true
  echo 'sampler_window_end'
fi

if [[ -f "$state/samples.csv" ]]; then
  python3 - "$state/samples.csv" <<'PY'
import csv, math, statistics, sys
p=sys.argv[1]
with open(p, newline='', encoding='utf-8') as f:
    rows=list(csv.DictReader(f))
print(f"sample_rows={len(rows)}")
if rows:
    print(f"sample_first_utc={rows[0].get('timestamp_utc','')}")
    print(f"sample_latest_utc={rows[-1].get('timestamp_utc','')}")
    fields=['total_sample_ms','seq_write_mib_s','small_create_files_s','sha256_mib_s','zstd_mib_s','docker_info_ms','https_total_ms']
    for field in fields:
        vals=[]
        for r in rows:
            try:
                v=float(r.get(field,''))
                if math.isfinite(v): vals.append(v)
            except (TypeError, ValueError): pass
        if vals:
            vals.sort()
            med=statistics.median(vals)
            p95=vals[min(len(vals)-1, math.ceil(.95*len(vals))-1)]
            print(f"{field}_median={med:.3f}")
            print(f"{field}_p95={p95:.3f}")
            print(f"{field}_min={vals[0]:.3f}")
            print(f"{field}_max={vals[-1]:.3f}")
PY
fi

if crontab -l 2>/dev/null | grep -q 'byte-p1-05-contention'; then
  echo 'sampler_cron_present=yes'
else
  echo 'sampler_cron_present=no'
fi
if [[ -d "$state/lock" ]]; then echo 'sampler_lock_present=yes'; else echo 'sampler_lock_present=no'; fi

echo 'status_complete=yes'
