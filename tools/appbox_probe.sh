#!/usr/bin/env bash
set -u

# Read-only tenant inventory probe for a Bytesized Appbox.
# No package installs, configuration changes, network transfers, benchmark data,
# arbitrary file-content reads, or recursive home-directory listings.

section() {
  printf '\n===== %s =====\n' "$1"
}

have() {
  command -v "$1" >/dev/null 2>&1
}

safe_run() {
  printf '$'
  printf ' %q' "$@"
  printf '\n'
  "$@" 2>&1 || true
}

probe_bool() {
  local label="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    printf '%s=yes\n' "$label"
  else
    printf '%s=no\n' "$label"
  fi
}

printf 'inventory_timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

section "tenant identity and OS"
safe_run id -u
safe_run id -g
safe_run id -G
safe_run uname -srmo
printf 'shell=%s\n' "${SHELL:-unknown}"
printf 'home_present=%s\n' "$([[ -d "${HOME:-/nonexistent}" ]] && echo yes || echo no)"
if [[ "${HOME:-}" =~ ^/home/[^/]+/[^/]+$ ]]; then
  echo 'home_layout=/home/<provider-segment>/<account>'
else
  echo 'home_layout=other'
fi
if [[ -r /etc/os-release ]]; then
  safe_run bash -lc '. /etc/os-release; printf "os_pretty=%s\\n" "$PRETTY_NAME"'
fi
if have bash; then
  safe_run bash --version
fi
if have getconf; then
  safe_run getconf GNU_LIBC_VERSION
fi

section "quota and filesystem"
if have quota; then
  safe_run quota -s
  safe_run quota -v
else
  echo 'quota=unavailable'
fi
safe_run df -hP "${HOME:-.}"
safe_run df -TP "${HOME:-.}"
if have stat; then
  safe_run stat -f -c 'filesystem_type=%T block_size=%S blocks=%b free_blocks=%f available_blocks=%a' "${HOME:-.}"
fi
if have findmnt; then
  safe_run findmnt -T "${HOME:-.}" -n -o FSTYPE,OPTIONS
fi

section "user limits"
safe_run bash -lc 'ulimit -a'
if have getconf; then
  safe_run getconf OPEN_MAX
  safe_run getconf CHILD_MAX
fi

section "host-reported shared resources"
echo 'NOTE: values in this section describe the shared host view, not tenant entitlement.'
if have nproc; then
  safe_run nproc --all
fi
if have free; then
  safe_run free -h
fi
if have lscpu; then
  safe_run bash -lc 'lscpu | grep -E "^(Architecture|CPU\(s\)|Model name|Socket\(s\)|Core\(s\) per socket|Thread\(s\) per core):"'
fi

section "tool availability"
tools=(
  git python3 python pip3 pip
  rsync rclone scp sftp
  tar gzip zstd xz zip unzip 7z
  sha256sum md5sum openssl
  curl wget jq sqlite3
  cron crontab systemctl
  docker
  gcc g++ make cmake
  node npm go rustc cargo
  ffmpeg
)
for tool in "${tools[@]}"; do
  if have "$tool"; then
    printf 'tool:%s=present path=%s\n' "$tool" "$(command -v "$tool")"
  else
    printf 'tool:%s=missing\n' "$tool"
  fi
done

section "selected tool versions"
have git && safe_run git --version
have python3 && safe_run python3 --version
have pip3 && safe_run pip3 --version
have rsync && safe_run bash -lc 'rsync --version | head -n 1'
have rclone && safe_run bash -lc 'rclone version | head -n 2'
have tar && safe_run bash -lc 'tar --version | head -n 1'
have gzip && safe_run bash -lc 'gzip --version | head -n 1'
have zstd && safe_run zstd --version
have xz && safe_run bash -lc 'xz --version | head -n 1'
have curl && safe_run bash -lc 'curl --version | head -n 1'
have wget && safe_run bash -lc 'wget --version | head -n 1'
have openssl && safe_run openssl version
have jq && safe_run jq --version
have sqlite3 && safe_run sqlite3 --version
have gcc && safe_run bash -lc 'gcc --version | head -n 1'
have g++ && safe_run bash -lc 'g++ --version | head -n 1'
have make && safe_run bash -lc 'make --version | head -n 1'
have cmake && safe_run bash -lc 'cmake --version | head -n 1'
have node && safe_run node --version
have npm && safe_run npm --version
have go && safe_run go version
have rustc && safe_run rustc --version
have cargo && safe_run cargo --version
have ffmpeg && safe_run bash -lc 'ffmpeg -version | head -n 1'

section "scheduler and user-service capability"
if have crontab; then
  echo 'crontab_command=present'
  if crontab -l >/dev/null 2>&1; then
    echo 'crontab_existing_entry_set=yes'
  else
    echo 'crontab_existing_entry_set=no_or_unreadable'
  fi
else
  echo 'crontab_command=missing'
fi
if have systemctl; then
  safe_run systemctl --user is-system-running
  probe_bool systemd_user_manager_responds systemctl --user show-environment
else
  echo 'systemctl=missing'
fi

section "docker and compose capability"
if have docker; then
  safe_run docker version --format 'client={{.Client.Version}} server={{if .Server}}{{.Server.Version}}{{else}}unavailable{{end}}'
  safe_run docker compose version
  safe_run docker context show
  if docker info >/dev/null 2>&1; then
    echo 'docker_server_responds=yes'
    safe_run docker info --format 'server_version={{.ServerVersion}} security_options={{json .SecurityOptions}}'
  else
    echo 'docker_server_responds=no'
  fi
else
  echo 'docker=missing'
fi

section "provider-directory conventions"
# Check only known/safe names; do not enumerate arbitrary user files.
if [[ "${HOME:-}" =~ ^/home/[^/]+/[^/]+$ ]]; then
  echo 'provider_home_shape=bytesized_style_two_level_home'
fi
for name in www .config .local .docker; do
  if [[ -e "${HOME:-/nonexistent}/$name" ]]; then
    printf 'known_path:%s=present\n' "$name"
  else
    printf 'known_path:%s=absent\n' "$name"
  fi
done

echo
echo 'Probe complete. Output is read-only inventory; redact account-specific identifiers before committing evidence.'
