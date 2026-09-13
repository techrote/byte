#!/usr/bin/env bash
set -euo pipefail

# P1-04 conservative single-stream network qualification.
# Runs on the trusted GitHub Actions runner and measures the exact SSH transport
# path already used by the programme. SSH compression is disabled so zero-filled
# payloads retain their intended byte count before encryption.

repetitions=3
inbound_mib=128
outbound_mib=32
max_outbound_mib=512

while (($#)); do
  case "$1" in
    --repetitions) shift; repetitions="${1:-}" ;;
    --inbound-mib) shift; inbound_mib="${1:-}" ;;
    --outbound-mib) shift; outbound_mib="${1:-}" ;;
    --help|-h)
      cat <<'EOF'
usage: qualify_network.sh [options]

Required environment:
  BYTE_HOST                 Appbox SSH host
  BYTE_USER                 Appbox SSH user
  BYTE_SSH_KEY_PATH         path to the dedicated private key
  BYTE_KNOWN_HOSTS_PATH     path to the pinned known_hosts file

Defaults deliberately stay far below the programme's 50 GB outbound ceiling:
  --repetitions N           2-5 (default 3)
  --inbound-mib N           16-512 per repetition (default 128)
  --outbound-mib N          4-128 per repetition (default 32)
EOF
      exit 0
      ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }
for value in "$repetitions" "$inbound_mib" "$outbound_mib"; do
  is_uint "$value" || { echo "numeric options must be positive integers" >&2; exit 2; }
done
(( repetitions >= 2 && repetitions <= 5 )) || { echo "repetitions must be 2-5" >&2; exit 2; }
(( inbound_mib >= 16 && inbound_mib <= 512 )) || { echo "inbound-mib must be 16-512" >&2; exit 2; }
(( outbound_mib >= 4 && outbound_mib <= 128 )) || { echo "outbound-mib must be 4-128" >&2; exit 2; }
planned_outbound_mib=$((repetitions * outbound_mib))
(( planned_outbound_mib <= max_outbound_mib )) || { echo "planned outbound exceeds ${max_outbound_mib} MiB script guardrail" >&2; exit 4; }

: "${BYTE_HOST:?BYTE_HOST is required}"
: "${BYTE_USER:?BYTE_USER is required}"
: "${BYTE_SSH_KEY_PATH:?BYTE_SSH_KEY_PATH is required}"
: "${BYTE_KNOWN_HOSTS_PATH:?BYTE_KNOWN_HOSTS_PATH is required}"

for tool in ssh dd wc date python3 mktemp rm; do
  command -v "$tool" >/dev/null 2>&1 || { echo "required tool missing: $tool" >&2; exit 3; }
done
[[ -r "$BYTE_SSH_KEY_PATH" ]] || { echo 'SSH key path is not readable' >&2; exit 3; }
[[ -r "$BYTE_KNOWN_HOSTS_PATH" ]] || { echo 'known_hosts path is not readable' >&2; exit 3; }

remote="$BYTE_USER@$BYTE_HOST"
control_dir=$(mktemp -d)
control_socket="$control_dir/cm.sock"
master_started=no

ssh_base=(
  -i "$BYTE_SSH_KEY_PATH"
  -o IdentitiesOnly=yes
  -o BatchMode=yes
  -o StrictHostKeyChecking=yes
  -o UserKnownHostsFile="$BYTE_KNOWN_HOSTS_PATH"
  -o ConnectTimeout=15
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=2
  -o Compression=no
  -T
)

cleanup() {
  local rc=$?
  trap - EXIT HUP INT TERM
  if [[ "$master_started" == yes ]]; then
    ssh "${ssh_base[@]}" -S "$control_socket" -O exit "$remote" >/dev/null 2>&1 || true
  fi
  rm -rf -- "$control_dir"
  exit "$rc"
}
trap cleanup EXIT HUP INT TERM

now_ns() { date +%s%N; }
elapsed_ms() {
  local start="$1" end="$2"
  printf '%d\n' "$(( (end - start) / 1000000 ))"
}
rate_mib_s() {
  python3 - "$1" "$2" <<'PY'
import sys
b = int(sys.argv[1]); ms = int(sys.argv[2])
print(f"{(b / 1048576) / (ms / 1000):.3f}" if ms > 0 else "inf")
PY
}

inbound_bytes=$((inbound_mib * 1024 * 1024))
outbound_bytes=$((outbound_mib * 1024 * 1024))

printf 'qualification=P1-04\n'
printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'endpoint=github_actions_runner_to_appbox_ssh\n'
printf 'repetitions=%d\n' "$repetitions"
printf 'inbound_bytes_per_rep=%d\n' "$inbound_bytes"
printf 'outbound_bytes_per_rep=%d\n' "$outbound_bytes"
printf 'planned_inbound_bytes=%d\n' "$((repetitions * inbound_bytes))"
printf 'planned_outbound_bytes=%d\n' "$((repetitions * outbound_bytes))"
printf 'ssh_compression=disabled\n'
printf 'provider_quota_counter_shell_visibility=not_observed\n'
printf 'measurement_columns=class,iteration,bytes,elapsed_ms,mib_per_s\n'

# Fresh authenticated setup samples, separated from sustained payload transfers.
for ((i=1; i<=repetitions; i++)); do
  start=$(now_ns)
  ssh "${ssh_base[@]}" "$remote" 'true'
  end=$(now_ns)
  ms=$(elapsed_ms "$start" "$end")
  printf 'measurement\tsetup\t%d\t0\t%d\tn/a\n' "$i" "$ms"
done

# Establish one pinned/authenticated control connection so payload samples mostly
# measure sustained single-stream transport rather than repeated authentication.
start=$(now_ns)
ssh "${ssh_base[@]}" -M -S "$control_socket" -fnNT "$remote"
master_started=yes
ssh "${ssh_base[@]}" -S "$control_socket" -O check "$remote" >/dev/null
end=$(now_ns)
master_ms=$(elapsed_ms "$start" "$end")
printf 'control_master_setup_ms=%d\n' "$master_ms"

# Inbound from the GitHub runner to the Appbox. Remote wc verifies exact bytes
# without creating any Appbox file.
for ((i=1; i<=repetitions; i++)); do
  start=$(now_ns)
  received=$(dd if=/dev/zero bs=1M count="$inbound_mib" status=none | \
    ssh "${ssh_base[@]}" -S "$control_socket" "$remote" 'LC_ALL=C wc -c')
  end=$(now_ns)
  received=${received//[[:space:]]/}
  [[ "$received" == "$inbound_bytes" ]] || {
    echo "inbound byte-count mismatch: expected $inbound_bytes got $received" >&2
    exit 5
  }
  ms=$(elapsed_ms "$start" "$end")
  rate=$(rate_mib_s "$inbound_bytes" "$ms")
  printf 'measurement\tinbound\t%d\t%d\t%d\t%s\n' "$i" "$inbound_bytes" "$ms" "$rate"
done

# Outbound from the Appbox to the GitHub runner. Local wc verifies exact bytes.
# This is the metered direction according to the provider model.
for ((i=1; i<=repetitions; i++)); do
  start=$(now_ns)
  received=$(ssh "${ssh_base[@]}" -S "$control_socket" "$remote" \
    "dd if=/dev/zero bs=1M count=$outbound_mib status=none" | LC_ALL=C wc -c)
  end=$(now_ns)
  received=${received//[[:space:]]/}
  [[ "$received" == "$outbound_bytes" ]] || {
    echo "outbound byte-count mismatch: expected $outbound_bytes got $received" >&2
    exit 5
  }
  ms=$(elapsed_ms "$start" "$end")
  rate=$(rate_mib_s "$outbound_bytes" "$ms")
  printf 'measurement\toutbound\t%d\t%d\t%d\t%s\n' "$i" "$outbound_bytes" "$ms" "$rate"
done

ssh "${ssh_base[@]}" -S "$control_socket" -O exit "$remote" >/dev/null
master_started=no
rm -rf -- "$control_dir"
trap - EXIT HUP INT TERM
printf 'finished_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'cleanup=pass\n'
printf 'qualification_complete=yes\n'
