#!/usr/bin/env bash
set -euo pipefail

# P1-04 conservative single-stream network qualification.
# Default traffic budget: 192 MiB inbound + 96 MiB outbound across three
# repetitions. The upload guardrail prevents accidental large qualification.

repetitions=3
download_mib=64
upload_mib=32
download_base='https://speed.cloudflare.com/__down'
upload_url='https://speed.cloudflare.com/__up'
max_outbound_mib=512

while (($#)); do
  case "$1" in
    --repetitions) shift; repetitions="${1:-}" ;;
    --download-mib) shift; download_mib="${1:-}" ;;
    --upload-mib) shift; upload_mib="${1:-}" ;;
    --download-base) shift; download_base="${1:-}" ;;
    --upload-url) shift; upload_url="${1:-}" ;;
    --help|-h)
      cat <<'EOF'
usage: qualify_network.sh [options]

Defaults deliberately stay far below the programme's 50 GB outbound ceiling:
  --repetitions N      2-5 (default 3)
  --download-mib N     16-96 per repetition (default 64)
  --upload-mib N       4-96 per repetition (default 32)
  --download-base URL  GET endpoint accepting ?bytes=N
  --upload-url URL     POST endpoint accepting an arbitrary request body
EOF
      exit 0
      ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }
for value in "$repetitions" "$download_mib" "$upload_mib"; do
  is_uint "$value" || { echo "numeric options must be positive integers" >&2; exit 2; }
done
(( repetitions >= 2 && repetitions <= 5 )) || { echo "repetitions must be 2-5" >&2; exit 2; }
(( download_mib >= 16 && download_mib <= 96 )) || { echo "download-mib must be 16-96" >&2; exit 2; }
(( upload_mib >= 4 && upload_mib <= 96 )) || { echo "upload-mib must be 4-96" >&2; exit 2; }
planned_outbound_mib=$((repetitions * upload_mib))
(( planned_outbound_mib <= max_outbound_mib )) || { echo "planned outbound exceeds ${max_outbound_mib} MiB script guardrail" >&2; exit 4; }

for tool in curl dd stat rm date; do
  command -v "$tool" >/dev/null 2>&1 || { echo "required tool missing: $tool" >&2; exit 3; }
done

work=$(mktemp -d "$HOME/.byte-p1-04-test.XXXXXX")
payload="$work/upload.bin"
cleanup() {
  local rc=$?
  trap - EXIT HUP INT TERM
  rm -rf -- "$work"
  exit "$rc"
}
trap cleanup EXIT HUP INT TERM

upload_bytes=$((upload_mib * 1024 * 1024))
download_bytes=$((download_mib * 1024 * 1024))
dd if=/dev/zero of="$payload" bs=1M count="$upload_mib" status=none
actual_payload=$(stat -c %s "$payload")
[[ "$actual_payload" -eq "$upload_bytes" ]] || { echo 'upload payload size mismatch' >&2; exit 5; }

printf 'qualification=P1-04\n'
printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'repetitions=%d\n' "$repetitions"
printf 'download_bytes_per_rep=%d\n' "$download_bytes"
printf 'upload_bytes_per_rep=%d\n' "$upload_bytes"
printf 'planned_inbound_bytes=%d\n' "$((repetitions * download_bytes))"
printf 'planned_outbound_bytes=%d\n' "$((repetitions * upload_bytes))"
printf 'curl_version=%s\n' "$(curl --version | head -n 1)"
printf 'provider_quota_counter_shell_visibility=not_observed\n'
printf 'measurement_columns=direction,iteration,requested_bytes,http_code,size_bytes,time_namelookup_s,time_connect_s,time_appconnect_s,time_starttransfer_s,time_total_s,speed_bytes_per_s\n'

curl_common=(
  --fail-with-body
  --silent
  --show-error
  --connect-timeout 15
  --max-time 120
  --retry 1
  --retry-delay 1
  -o /dev/null
)

# Small unreported TLS warm-up. This bounds first-request DNS/TLS surprises without
# materially affecting the traffic budget; measured repetitions still include
# their own connection/setup timings.
curl "${curl_common[@]}" "${download_base}?bytes=65536" >/dev/null

for ((i=1; i<=repetitions; i++)); do
  printf 'measurement\tinbound\t%d\t%d\t' "$i" "$download_bytes"
  curl "${curl_common[@]}" \
    -w '%{http_code}\t%{size_download}\t%{time_namelookup}\t%{time_connect}\t%{time_appconnect}\t%{time_starttransfer}\t%{time_total}\t%{speed_download}\n' \
    "${download_base}?bytes=${download_bytes}"
done

for ((i=1; i<=repetitions; i++)); do
  printf 'measurement\toutbound\t%d\t%d\t' "$i" "$upload_bytes"
  curl "${curl_common[@]}" \
    -X POST \
    -H 'Content-Type: application/octet-stream' \
    --data-binary "@$payload" \
    -w '%{http_code}\t%{size_upload}\t%{time_namelookup}\t%{time_connect}\t%{time_appconnect}\t%{time_starttransfer}\t%{time_total}\t%{speed_upload}\n' \
    "$upload_url"
done

rm -rf -- "$work"
trap - EXIT HUP INT TERM
printf 'finished_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'cleanup=pass\n'
printf 'qualification_complete=yes\n'
