#!/usr/bin/env bash
set -u

# Non-destructive first-contact probe for a Bytesized Appbox.
# It intentionally avoids network transfers, writes, stress tests and secrets.
# Review output before committing it because provider/account identifiers may be
# visible in commands supplied by the platform.

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

section "identity (numeric/minimal)"
safe_run id -u
safe_run id -g
safe_run id -G
safe_run uname -srmo
printf 'shell=%s\n' "${SHELL:-unknown}"
printf 'home_present=%s\n' "$([[ -d "${HOME:-/nonexistent}" ]] && echo yes || echo no)"

section "quota and filesystem"
if have quota; then
  safe_run quota -s
else
  echo "quota: unavailable"
fi
safe_run df -h "${HOME:-.}"
safe_run df -T "${HOME:-.}"

section "limits"
safe_run bash -lc 'ulimit -a'

section "tool availability"
for tool in git python3 python pip3 pip rsync rclone tar gzip zstd xz sha256sum curl wget cron crontab systemctl docker; do
  if have "$tool"; then
    printf '%-12s %s\n' "$tool" "$(command -v "$tool")"
  else
    printf '%-12s %s\n' "$tool" "MISSING"
  fi
done

if have docker; then
  section "docker client"
  safe_run docker version --format 'client={{.Client.Version}} server={{if .Server}}{{.Server.Version}}{{else}}unavailable{{end}}'
  safe_run docker compose version
fi

section "user service/scheduler hints"
if have systemctl; then
  safe_run systemctl --user is-system-running
fi
if have crontab; then
  safe_run crontab -l
fi

section "directory overview"
# Limit depth/output; do not print arbitrary file contents.
safe_run bash -lc 'find "$HOME" -mindepth 1 -maxdepth 1 -printf "%f\n" 2>/dev/null | sort | head -100'

echo
echo "Probe complete. Review/redact account-specific identifiers before committing output."
