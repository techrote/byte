#!/usr/bin/env bash
set -euo pipefail

# P1-02 final exact-scope cleanup. Alpine 3.20 was absent before the first
# mutation run and was left cached only because that run failed before cleanup.

export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
project_root="$HOME/.byte-p1-02-qual"

for name in byte-p1-02-smoke byte-p1-02-persist byte-p1-02-web; do
  docker rm -f "$name" >/dev/null 2>&1 || true
done
rm -rf "$project_root"
docker network rm byte-p1-02_default >/dev/null 2>&1 || true

alpine_users=$(docker ps -a --filter ancestor=alpine:3.20 -q)
if [[ -n "$alpine_users" ]]; then
  echo 'final_alpine_cleanup=preserved_in_use'
else
  if docker image inspect alpine:3.20 >/dev/null 2>&1; then
    docker image rm alpine:3.20 >/dev/null
    echo 'final_alpine_cleanup=removed'
  else
    echo 'final_alpine_cleanup=already_absent'
  fi
fi

if docker ps -a --format '{{.Names}}' | grep -Eq '^byte-p1-02-(smoke|persist|web)$'; then
  echo 'final_container_cleanup=fail' >&2
  exit 1
fi
if docker network inspect byte-p1-02_default >/dev/null 2>&1; then
  echo 'final_network_cleanup=fail' >&2
  exit 1
fi
if [[ -e "$project_root" ]]; then
  echo 'final_bind_data_cleanup=fail' >&2
  exit 1
fi

echo 'final_container_cleanup=pass'
echo 'final_network_cleanup=pass'
echo 'final_bind_data_cleanup=pass'
echo 'docker_system_df_final_begin'
docker system df
echo 'docker_system_df_final_end'
echo 'final_cleanup=pass'
