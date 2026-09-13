#!/usr/bin/env bash
set -euo pipefail

# P1-03 bounded Appbox storage qualification.
# Uses ordinary filesystem operations only inside a disposable directory under
# the user's home quota. No raw devices, direct I/O, cache dropping or fio.

repetitions=3
seq_mib=1024
small_files=5000
archive_files=2048
archive_kib=32
min_free_gib=8

while (($#)); do
  case "$1" in
    --repetitions) shift; repetitions="${1:-}" ;;
    --seq-mib) shift; seq_mib="${1:-}" ;;
    --small-files) shift; small_files="${1:-}" ;;
    --archive-files) shift; archive_files="${1:-}" ;;
    --archive-kib) shift; archive_kib="${1:-}" ;;
    --help|-h)
      cat <<'EOF'
usage: qualify_storage.sh [options]

Options:
  --repetitions N     repetitions per measured task (default 3)
  --seq-mib N         sequential test-file size in MiB (default 1024; 1024-4096)
  --small-files N     small-file count per metadata cycle (default 5000)
  --archive-files N   files in synthetic archive tree (default 2048)
  --archive-kib N     KiB per synthetic archive file (default 32)
EOF
      exit 0
      ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

is_uint() { [[ "$1" =~ ^[0-9]+$ ]]; }
for value in "$repetitions" "$seq_mib" "$small_files" "$archive_files" "$archive_kib"; do
  is_uint "$value" || { echo "all numeric options must be positive integers" >&2; exit 2; }
done
(( repetitions >= 2 && repetitions <= 5 )) || { echo "repetitions must be 2-5" >&2; exit 2; }
(( seq_mib >= 1024 && seq_mib <= 4096 && seq_mib % 8 == 0 )) || { echo "seq-mib must be 1024-4096 and divisible by 8" >&2; exit 2; }
(( small_files >= 1000 && small_files <= 20000 )) || { echo "small-files must be 1000-20000" >&2; exit 2; }
(( archive_files >= 256 && archive_files <= 4096 )) || { echo "archive-files must be 256-4096" >&2; exit 2; }
(( archive_kib >= 4 && archive_kib <= 128 )) || { echo "archive-kib must be 4-128" >&2; exit 2; }

for tool in dd cp rm stat tar sha256sum python3 zstd quota df sync; do
  command -v "$tool" >/dev/null 2>&1 || { echo "required tool missing: $tool" >&2; exit 3; }
done

redact() {
  sed \
    -e "s#${HOME//\#/\\#}#<HOME>#g" \
    -e "s#${USER:-__NO_USER__}#<USER>#g"
}

now_ns() { date +%s%N; }

run_timed() {
  local metric="$1" iteration="$2" bytes="$3"
  shift 3
  local start end ms
  start=$(now_ns)
  "$@"
  end=$(now_ns)
  ms=$(( (end - start) / 1000000 ))
  printf 'measurement\t%s\t%s\t%s\t%s\n' "$metric" "$iteration" "$ms" "$bytes"
}

quota_snapshot() {
  local phase="$1"
  printf 'quota_%s_begin\n' "$phase"
  quota -w -v 2>&1 | redact | head -n 20 || true
  printf 'quota_%s_end\n' "$phase"
  printf 'df_%s_begin\n' "$phase"
  df -Pk "$HOME" 2>&1 | redact | head -n 3 || true
  printf 'df_%s_end\n' "$phase"
}

quota_numeric_preflight() {
  local line used limit free_blocks required_blocks
  line=$(quota -w -v 2>/dev/null | awk '$2 ~ /^[0-9]+$/ && $4 ~ /^[0-9]+$/ && $4 > 0 {print $2, $4; exit}')
  if [[ -z "$line" ]]; then
    echo 'quota_numeric_preflight=unavailable'
    return 0
  fi
  read -r used limit <<<"$line"
  free_blocks=$((limit - used))
  required_blocks=$((min_free_gib * 1024 * 1024))
  printf 'quota_numeric_used_blocks=%s\n' "$used"
  printf 'quota_numeric_limit_blocks=%s\n' "$limit"
  printf 'quota_numeric_free_blocks=%s\n' "$free_blocks"
  if (( free_blocks < required_blocks )); then
    echo "quota preflight: less than ${min_free_gib} GiB headroom" >&2
    exit 4
  fi
  echo 'quota_numeric_preflight=pass'
}

work=$(mktemp -d "$HOME/.byte-p1-03-test.XXXXXX")
running_marker="$HOME/.byte-p1-03-running"
cleanup() {
  local rc=$?
  rm -rf -- "$work"
  rm -f -- "$running_marker"
  exit "$rc"
}
trap cleanup EXIT HUP INT TERM
: > "$running_marker"

printf 'qualification=P1-03\n'
printf 'started_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'repetitions=%d\n' "$repetitions"
printf 'sequential_mib=%d\n' "$seq_mib"
printf 'small_files=%d\n' "$small_files"
printf 'archive_files=%d\n' "$archive_files"
printf 'archive_kib_each=%d\n' "$archive_kib"
printf 'filesystem=%s\n' "$(stat -f -c %T "$HOME" 2>/dev/null || echo unknown)"
printf 'dd_version=%s\n' "$(dd --version | head -n 1 | redact)"
printf 'tar_version=%s\n' "$(tar --version | head -n 1 | redact)"
printf 'zstd_version=%s\n' "$(zstd --version | head -n 1 | redact)"
printf 'python_version=%s\n' "$(python3 --version 2>&1 | redact)"

quota_snapshot before
quota_numeric_preflight
available_kib=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
required_kib=$((min_free_gib * 1024 * 1024))
if ! is_uint "$available_kib" || (( available_kib < required_kib )); then
  echo "filesystem preflight: less than ${min_free_gib} GiB visible free space" >&2
  exit 4
fi
printf 'df_available_kib_preflight=%s\n' "$available_kib"

seq_bytes=$((seq_mib * 1024 * 1024))
seq_blocks=$((seq_mib / 8))
seq_file="$work/sequential.bin"
seq_copy="$work/sequential.copy"
hash_out="$work/sequential.sha256"

seq_create() {
  dd if=/dev/zero of="$seq_file" bs=8M count="$seq_blocks" conv=fdatasync status=none
}
seq_read() {
  dd if="$seq_file" of=/dev/null bs=8M status=none
}
seq_copy_file() {
  cp --reflink=never "$seq_file" "$seq_copy"
  sync "$seq_copy"
}
seq_hash() {
  sha256sum "$seq_file" > "$hash_out"
}
seq_delete() {
  rm -f -- "$seq_copy" "$seq_file" "$hash_out"
}

for ((i=1; i<=repetitions; i++)); do
  run_timed seq_create "$i" "$seq_bytes" seq_create
  run_timed seq_read_buffered "$i" "$seq_bytes" seq_read
  run_timed seq_copy_fsync "$i" "$seq_bytes" seq_copy_file
  run_timed sha256 "$i" "$seq_bytes" seq_hash
  run_timed seq_delete "$i" "$((seq_bytes * 2))" seq_delete
done

small_dir="$work/small-files"
small_create() {
  python3 - "$small_dir" "$small_files" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1]); count = int(sys.argv[2])
per_dir = 50
payload = b'x' * 128
for i in range(count):
    d = root / f'd{i // per_dir:04d}'
    d.mkdir(parents=True, exist_ok=True)
    (d / f'f{i:06d}.dat').write_bytes(payload)
PY
}
small_stat_read() {
  python3 - "$small_dir" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1]); total = 0
for p in root.rglob('*.dat'):
    st = p.stat()
    with p.open('rb') as fh:
        total += st.st_size + len(fh.read(1))
if total <= 0:
    raise SystemExit('small-file verification produced no data')
PY
}
small_delete() { rm -rf -- "$small_dir"; }

for ((i=1; i<=repetitions; i++)); do
  run_timed small_create "$i" "$small_files" small_create
  run_timed small_stat_read "$i" "$small_files" small_stat_read
  run_timed small_delete "$i" "$small_files" small_delete
done

archive_src="$work/archive-src"
mkdir -p "$archive_src"
python3 - "$archive_src" "$archive_files" "$archive_kib" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1]); count = int(sys.argv[2]); kib = int(sys.argv[3])
per_dir = 16
base = (b'byte-appbox-storage-qualification\n' * 2048)
for i in range(count):
    d = root / f'd{i // per_dir:04d}'
    d.mkdir(parents=True, exist_ok=True)
    prefix = f'file={i:06d}\n'.encode()
    need = kib * 1024
    data = (prefix + base * ((need // len(base)) + 2))[:need]
    (d / f'f{i:06d}.dat').write_bytes(data)
PY
archive_payload_bytes=$((archive_files * archive_kib * 1024))
archive_tar="$work/archive.tar"
archive_zst="$work/archive.tar.zst"
archive_roundtrip="$work/archive.roundtrip.tar"
extract_dir="$work/extract"

archive_create() { tar -cf "$archive_tar" -C "$archive_src" .; sync "$archive_tar"; }
archive_extract() { rm -rf -- "$extract_dir"; mkdir -p "$extract_dir"; tar -xf "$archive_tar" -C "$extract_dir"; }
archive_compress() { zstd -q -3 -f "$archive_tar" -o "$archive_zst"; }
archive_decompress() { zstd -q -d -f "$archive_zst" -o "$archive_roundtrip"; cmp -s "$archive_tar" "$archive_roundtrip"; }
archive_cleanup_cycle() { rm -rf -- "$extract_dir" "$archive_tar" "$archive_zst" "$archive_roundtrip"; }

for ((i=1; i<=repetitions; i++)); do
  run_timed archive_create "$i" "$archive_payload_bytes" archive_create
  run_timed archive_extract "$i" "$archive_payload_bytes" archive_extract
  run_timed zstd_compress_level3 "$i" "$archive_payload_bytes" archive_compress
  compressed_bytes=$(stat -c %s "$archive_zst")
  printf 'compressed_bytes\t%s\t%s\n' "$i" "$compressed_bytes"
  run_timed zstd_decompress "$i" "$archive_payload_bytes" archive_decompress
  archive_cleanup_cycle
done

rm -rf -- "$archive_src"
rm -f -- "$running_marker"
rmdir "$work"
trap - EXIT HUP INT TERM

quota_snapshot after
printf 'finished_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'cleanup=pass\n'
printf 'qualification_complete=yes\n'
