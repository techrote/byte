#!/usr/bin/env bash
set -euo pipefail

# P1-05 low-impact shared-host contention sampler.
#
# Default schedule: one short sample every 30 minutes for 48 hours. The tool
# retains only a 32 MiB CPU seed plus CSV/log metadata between runs. Per-sample
# filesystem state is disposable and removed by a trap. No raw devices, direct
# I/O, cache dropping, multi-stream network load, or sustained CPU loops.

mode="once"
duration_hours=48
state_dir="${BYTE_P1_05_STATE_DIR:-$HOME/.byte-p1-05}"
marker="# byte-p1-05-contention"
interval_minutes=30
seq_mib=64
small_files=1000
seed_mib=32

usage() {
  cat <<'EOF'
usage: sample_contention.sh [--once | --install [HOURS] | --status | --uninstall]

  --once             run one bounded sample (default)
  --install [HOURS]  install a 30-minute cron sampler for 24-72 hours
                     (default 48), create seed/state, and take one sample now
  --status           report schedule/sample state without running a sample
  --uninstall        remove only the P1-05 cron entry; retain evidence/state

Environment:
  BYTE_P1_05_STATE_DIR  override state directory (default ~/.byte-p1-05)
EOF
}

while (($#)); do
  case "$1" in
    --once) mode="once" ;;
    --install)
      mode="install"
      if [[ "${2:-}" =~ ^[0-9]+$ ]]; then
        duration_hours="$2"
        shift
      fi
      ;;
    --status) mode="status" ;;
    --uninstall) mode="uninstall" ;;
    --help|-h) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$state_dir" =~ [[:space:]] ]]; then
  echo 'state directory containing whitespace is unsupported for the cron installer' >&2
  exit 2
fi

for tool in awk crontab curl date dd df docker grep mkdir mktemp python3 quota rm sed sha256sum stat wc zstd; do
  command -v "$tool" >/dev/null 2>&1 || { echo "required tool missing: $tool" >&2; exit 3; }
done

mkdir -p "$state_dir"
meta_file="$state_dir/window.env"
csv_file="$state_dir/samples.csv"
events_file="$state_dir/events.log"
seed_file="$state_dir/cpu-seed.bin"
lock_dir="$state_dir/lock"
tmp_root="$state_dir/tmp"
installed_script="$state_dir/bin/sample_contention.sh"
mkdir -p "$tmp_root"

now_ns() { date +%s%N; }
ms_between() {
  awk -v a="$1" -v b="$2" 'BEGIN { printf "%.3f", (b-a)/1000000.0 }'
}
rate_mib_s() {
  awk -v mib="$1" -v a="$2" -v b="$3" 'BEGIN { d=(b-a)/1000000000.0; if (d>0) printf "%.3f", mib/d }'
}
rate_count_s() {
  awk -v n="$1" -v a="$2" -v b="$3" 'BEGIN { d=(b-a)/1000000000.0; if (d>0) printf "%.3f", n/d }'
}
seconds_to_ms() {
  awk -v s="$1" 'BEGIN { if (s != "") printf "%.3f", s*1000.0 }'
}

append_event() {
  printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >> "$events_file"
}

ensure_header() {
  if [[ ! -s "$csv_file" ]]; then
    printf '%s\n' 'timestamp_utc,epoch,seq_write_rc,seq_write_ms,seq_write_mib_s,small_create_rc,small_create_ms,small_create_files_s,small_stat_rc,small_stat_ms,small_stat_files_s,small_delete_rc,small_delete_ms,small_delete_files_s,sha256_rc,sha256_ms,sha256_mib_s,zstd_rc,zstd_ms,zstd_mib_s,docker_info_rc,docker_info_ms,docker_running_containers,https_route_found,https_curl_rc,https_http_code,https_dns_ms,https_connect_ms,https_tls_ms,https_ttfb_ms,https_total_ms,quota_used_kib,quota_limit_kib,df_available_kib,total_sample_ms' > "$csv_file"
  fi
}

quota_numbers() {
  quota -w -v 2>/dev/null | awk '$2 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ && $4 > 0 {print $2, $4; exit}' || true
}

install_cron() {
  local current filtered cron_line log_file
  current=$(crontab -l 2>/dev/null || true)
  filtered=$(printf '%s\n' "$current" | grep -Fv "$marker" || true)
  log_file="$state_dir/cron.log"
  cron_line="*/${interval_minutes} * * * * ${installed_script} --once >> ${log_file} 2>&1 ${marker}"
  {
    [[ -n "$filtered" ]] && printf '%s\n' "$filtered"
    printf '%s\n' "$cron_line"
  } | crontab -
}

remove_cron() {
  local current filtered
  current=$(crontab -l 2>/dev/null || true)
  filtered=$(printf '%s\n' "$current" | grep -Fv "$marker" || true)
  if [[ -n "${filtered//[[:space:]]/}" ]]; then
    printf '%s\n' "$filtered" | crontab -
  else
    crontab -r 2>/dev/null || true
  fi
}

if [[ "$mode" == "install" ]]; then
  [[ "$duration_hours" =~ ^[0-9]+$ ]] || { echo 'duration must be an integer' >&2; exit 2; }
  (( duration_hours >= 24 && duration_hours <= 72 )) || { echo 'duration must be 24-72 hours' >&2; exit 2; }

  mkdir -p "$state_dir/bin" "$tmp_root"
  cp -- "$0" "$installed_script"
  chmod 700 "$installed_script"

  if [[ ! -s "$seed_file" ]]; then
    dd if=/dev/urandom of="$seed_file" bs=1M count="$seed_mib" conv=fdatasync status=none
    chmod 600 "$seed_file"
  fi

  start_epoch=$(date +%s)
  end_epoch=$((start_epoch + duration_hours * 3600))
  cat > "$meta_file" <<EOF
start_epoch=$start_epoch
end_epoch=$end_epoch
interval_minutes=$interval_minutes
duration_hours=$duration_hours
seq_mib=$seq_mib
small_files=$small_files
seed_mib=$seed_mib
EOF
  chmod 600 "$meta_file"
  ensure_header
  install_cron
  append_event "installed duration_hours=$duration_hours interval_minutes=$interval_minutes"

  printf 'sampling_install=pass\n'
  printf 'duration_hours=%d\n' "$duration_hours"
  printf 'interval_minutes=%d\n' "$interval_minutes"
  printf 'start_utc=%s\n' "$(date -u -d "@$start_epoch" +%Y-%m-%dT%H:%M:%SZ)"
  printf 'end_utc=%s\n' "$(date -u -d "@$end_epoch" +%Y-%m-%dT%H:%M:%SZ)"
  printf 'persistent_seed_mib=%d\n' "$seed_mib"
  printf 'peak_disposable_mib_approx=%d\n' "$((seq_mib + 2))"
  printf 'cron_marker_present=yes\n'
  exec "$installed_script" --once
fi

if [[ "$mode" == "uninstall" ]]; then
  remove_cron
  append_event 'cron_uninstalled'
  echo 'cron_marker_present=no'
  echo 'sampling_state_retained=yes'
  exit 0
fi

if [[ "$mode" == "status" ]]; then
  if [[ -f "$meta_file" ]]; then
    # shellcheck disable=SC1090
    source "$meta_file"
    printf 'start_utc=%s\n' "$(date -u -d "@$start_epoch" +%Y-%m-%dT%H:%M:%SZ)"
    printf 'end_utc=%s\n' "$(date -u -d "@$end_epoch" +%Y-%m-%dT%H:%M:%SZ)"
    printf 'window_complete=%s\n' "$([[ $(date +%s) -gt $end_epoch ]] && echo yes || echo no)"
  else
    echo 'sampling_window=not_installed'
  fi
  if [[ -f "$csv_file" ]]; then
    rows=$(awk 'END {print (NR>0 ? NR-1 : 0)}' "$csv_file")
  else
    rows=0
  fi
  printf 'sample_rows=%s\n' "$rows"
  printf 'state_kib=%s\n' "$(du -sk "$state_dir" 2>/dev/null | awk '{print $1}' || echo unknown)"
  cron_present=no
  crontab -l 2>/dev/null | grep -Fq "$marker" && cron_present=yes || true
  printf 'cron_marker_present=%s\n' "$cron_present"
  printf 'lock_present=%s\n' "$([[ -d "$lock_dir" ]] && echo yes || echo no)"
  exit 0
fi

# --once
if [[ ! -f "$meta_file" ]]; then
  echo 'sampling window is not installed' >&2
  exit 4
fi
# shellcheck disable=SC1090
source "$meta_file"

now_epoch=$(date +%s)
if (( now_epoch > end_epoch )); then
  append_event 'window_complete_no_sample'
  echo 'sampling_window=complete'
  exit 0
fi

# Atomic non-overlap lock with conservative stale recovery.
if ! mkdir "$lock_dir" 2>/dev/null; then
  lock_mtime=$(stat -c %Y "$lock_dir" 2>/dev/null || echo "$now_epoch")
  if (( now_epoch - lock_mtime > 900 )); then
    rm -rf -- "$lock_dir"
    if ! mkdir "$lock_dir" 2>/dev/null; then
      append_event 'sample_skipped_overlap_after_stale_recovery'
      echo 'sampling=skipped_overlap'
      exit 0
    fi
    append_event 'stale_lock_recovered'
  else
    append_event 'sample_skipped_overlap'
    echo 'sampling=skipped_overlap'
    exit 0
  fi
fi

sample_dir=$(mktemp -d "$tmp_root/sample.XXXXXX")
cleanup() {
  local rc=$?
  trap - EXIT HUP INT TERM
  rm -rf -- "$sample_dir"
  rmdir "$lock_dir" 2>/dev/null || rm -rf -- "$lock_dir"
  exit "$rc"
}
trap cleanup EXIT HUP INT TERM

if [[ ! -s "$seed_file" ]]; then
  append_event 'sample_skipped_seed_missing'
  echo 'sampling=skipped_seed_missing' >&2
  exit 5
fi

# Guardrails: require at least 2 GiB visible filesystem headroom and, where
# quota is readable, at least 2 GiB beneath the hard quota.
available_kib=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
if [[ ! "$available_kib" =~ ^[0-9]+$ ]] || (( available_kib < 2 * 1024 * 1024 )); then
  append_event 'sample_skipped_low_filesystem_headroom'
  echo 'sampling=skipped_low_filesystem_headroom'
  exit 0
fi
quota_line=$(quota_numbers)
quota_used=""
quota_limit=""
if [[ -n "$quota_line" ]]; then
  read -r quota_used quota_limit <<<"$quota_line"
  if (( quota_limit - quota_used < 2 * 1024 * 1024 )); then
    append_event 'sample_skipped_low_quota_headroom'
    echo 'sampling=skipped_low_quota_headroom'
    exit 0
  fi
fi

sample_start_ns=$(now_ns)
timestamp_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
epoch=$(date +%s)

# 1) Short ordinary durable sequential write: 64 MiB by default.
seq_file="$sample_dir/sequential.bin"
seq_start=$(now_ns)
set +e
dd if=/dev/zero of="$seq_file" bs=8M count=$((seq_mib / 8)) conv=fdatasync status=none
seq_rc=$?
set -e
seq_end=$(now_ns)
seq_ms=$(ms_between "$seq_start" "$seq_end")
seq_rate=""
[[ "$seq_rc" -eq 0 ]] && seq_rate=$(rate_mib_s "$seq_mib" "$seq_start" "$seq_end")
rm -f -- "$seq_file"

# 2) Small-file metadata create/stat/read/delete cycle.
small_dir="$sample_dir/small"
small_create_start=$(now_ns)
set +e
python3 - "$small_dir" "$small_files" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1]); count = int(sys.argv[2])
payload = b'x' * 128
for i in range(count):
    d = root / f'd{i // 50:04d}'
    d.mkdir(parents=True, exist_ok=True)
    (d / f'f{i:06d}.dat').write_bytes(payload)
PY
small_create_rc=$?
set -e
small_create_end=$(now_ns)
small_create_ms=$(ms_between "$small_create_start" "$small_create_end")
small_create_rate=""
[[ "$small_create_rc" -eq 0 ]] && small_create_rate=$(rate_count_s "$small_files" "$small_create_start" "$small_create_end")

small_stat_start=$(now_ns)
set +e
python3 - "$small_dir" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1]); total = 0
for p in root.rglob('*.dat'):
    st = p.stat()
    with p.open('rb') as fh:
        total += st.st_size + len(fh.read(1))
if total <= 0:
    raise SystemExit(1)
PY
small_stat_rc=$?
set -e
small_stat_end=$(now_ns)
small_stat_ms=$(ms_between "$small_stat_start" "$small_stat_end")
small_stat_rate=""
[[ "$small_stat_rc" -eq 0 ]] && small_stat_rate=$(rate_count_s "$small_files" "$small_stat_start" "$small_stat_end")

small_delete_start=$(now_ns)
set +e
rm -rf -- "$small_dir"
small_delete_rc=$?
set -e
small_delete_end=$(now_ns)
small_delete_ms=$(ms_between "$small_delete_start" "$small_delete_end")
small_delete_rate=""
[[ "$small_delete_rc" -eq 0 ]] && small_delete_rate=$(rate_count_s "$small_files" "$small_delete_start" "$small_delete_end")

# 3) CPU/utility work against a retained 32 MiB deterministic-size seed.
hash_start=$(now_ns)
set +e
sha256sum "$seed_file" >/dev/null
hash_rc=$?
set -e
hash_end=$(now_ns)
hash_ms=$(ms_between "$hash_start" "$hash_end")
hash_rate=""
[[ "$hash_rc" -eq 0 ]] && hash_rate=$(rate_mib_s "$seed_mib" "$hash_start" "$hash_end")

zstd_start=$(now_ns)
set +e
zstd -3 -q -c "$seed_file" >/dev/null
zstd_rc=$?
set -e
zstd_end=$(now_ns)
zstd_ms=$(ms_between "$zstd_start" "$zstd_end")
zstd_rate=""
[[ "$zstd_rc" -eq 0 ]] && zstd_rate=$(rate_mib_s "$seed_mib" "$zstd_start" "$zstd_end")

# 4) Rootless Docker daemon responsiveness and current running-container count.
export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
docker_start=$(now_ns)
set +e
docker info --format '{{.ServerVersion}}' >/dev/null 2>&1
docker_info_rc=$?
set -e
docker_end=$(now_ns)
docker_info_ms=$(ms_between "$docker_start" "$docker_end")
docker_running=""
if [[ "$docker_info_rc" -eq 0 ]]; then
  docker_running=$(docker ps -q 2>/dev/null | wc -l | awk '{print $1}')
fi

# 5) One tiny provider-managed HTTPS timing observation. Discover a running
# tenant *.bysh.me route from Docker labels, but never persist or print hostname.
route_host=$(
  {
    for id in $(docker ps -q 2>/dev/null); do
      docker inspect -f '{{range $k,$v := .Config.Labels}}{{printf "%s=%s\n" $k $v}}{{end}}' "$id" 2>/dev/null || true
    done
  } | grep -Eo '[A-Za-z0-9.-]+\.bysh\.me' | head -n 1 || true
)
https_route_found=no
https_curl_rc=""
https_http=""
https_dns_ms=""
https_connect_ms=""
https_tls_ms=""
https_ttfb_ms=""
https_total_ms=""
if [[ -n "$route_host" ]]; then
  https_route_found=yes
  set +e
  curl_metrics=$(curl --silent --output /dev/null --connect-timeout 5 --max-time 10 \
    --write-out '%{http_code},%{time_namelookup},%{time_connect},%{time_appconnect},%{time_starttransfer},%{time_total}' \
    "https://$route_host/" 2>/dev/null)
  https_curl_rc=$?
  set -e
  IFS=, read -r https_http https_dns_s https_connect_s https_tls_s https_ttfb_s https_total_s <<<"${curl_metrics:-,,,,,}"
  https_dns_ms=$(seconds_to_ms "${https_dns_s:-}")
  https_connect_ms=$(seconds_to_ms "${https_connect_s:-}")
  https_tls_ms=$(seconds_to_ms "${https_tls_s:-}")
  https_ttfb_ms=$(seconds_to_ms "${https_ttfb_s:-}")
  https_total_ms=$(seconds_to_ms "${https_total_s:-}")
fi

# Refresh space/quota state after the disposable workload has been removed.
available_kib=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
quota_line=$(quota_numbers)
if [[ -n "$quota_line" ]]; then
  read -r quota_used quota_limit <<<"$quota_line"
fi

sample_end_ns=$(now_ns)
total_ms=$(ms_between "$sample_start_ns" "$sample_end_ns")
ensure_header
printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
  "$timestamp_utc" "$epoch" \
  "$seq_rc" "$seq_ms" "$seq_rate" \
  "$small_create_rc" "$small_create_ms" "$small_create_rate" \
  "$small_stat_rc" "$small_stat_ms" "$small_stat_rate" \
  "$small_delete_rc" "$small_delete_ms" "$small_delete_rate" \
  "$hash_rc" "$hash_ms" "$hash_rate" \
  "$zstd_rc" "$zstd_ms" "$zstd_rate" \
  "$docker_info_rc" "$docker_info_ms" "$docker_running" \
  "$https_route_found" "$https_curl_rc" "$https_http" \
  "$https_dns_ms" "$https_connect_ms" "$https_tls_ms" "$https_ttfb_ms" "$https_total_ms" \
  "$quota_used" "$quota_limit" "$available_kib" "$total_ms" >> "$csv_file"

append_event "sample_pass epoch=$epoch total_ms=$total_ms"
printf 'sampling=pass\n'
printf 'timestamp_utc=%s\n' "$timestamp_utc"
printf 'sample_rows=%s\n' "$(awk 'END {print NR-1}' "$csv_file")"
printf 'sample_total_ms=%s\n' "$total_ms"
printf 'seq_write_mib_s=%s\n' "$seq_rate"
printf 'sha256_mib_s=%s\n' "$hash_rate"
printf 'zstd_mib_s=%s\n' "$zstd_rate"
printf 'docker_info_ms=%s\n' "$docker_info_ms"
printf 'https_route_found=%s\n' "$https_route_found"
printf 'https_total_ms=%s\n' "$https_total_ms"
printf 'disposable_cleanup=trap_armed\n'
