#!/usr/bin/env bash
set -euo pipefail

# Default remote task for the trusted `remote/` PR execution lane.
# Keep this intentionally read-only. Issue branches may replace this file with a
# bounded, versioned task appropriate to that issue; fork PRs never receive the
# Appbox credentials.

printf 'remote_exec=ok\n'
printf 'uid=%s\n' "$(id -u)"
printf 'gid=%s\n' "$(id -g)"
printf 'kernel=%s\n' "$(uname -srmo)"
printf 'shell=%s\n' "${SHELL:-unknown}"

if command -v quota >/dev/null 2>&1; then
  echo 'quota=available'
else
  echo 'quota=missing'
fi

if df -h "$HOME" >/dev/null 2>&1; then
  df -h "$HOME" | awk 'NR==1 || NR==2 {print}'
fi

for tool in git python3 rsync rclone tar gzip zstd sha256sum curl cron crontab systemctl docker; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'tool:%s=present\n' "$tool"
  else
    printf 'tool:%s=missing\n' "$tool"
  fi
done

if command -v docker >/dev/null 2>&1; then
  docker version --format 'docker_client={{.Client.Version}} docker_server={{if .Server}}{{.Server.Version}}{{else}}unavailable{{end}}' 2>/dev/null || true
  docker compose version 2>/dev/null || true
fi

printf 'remote_probe=complete\n'
