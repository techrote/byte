#!/usr/bin/env bash
set -euo pipefail

# P1-02 trusted remote task: bounded rootless-Docker mutation qualification.
# It only creates resources with the byte-p1-02 prefix and intentionally leaves
# them running long enough for GitHub Actions to verify HTTPS from off-host.

export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"

project_name="byte-p1-02"
project_root="$HOME/.byte-p1-02-qual"
data_dir="$project_root/data"
network="traefik_${USER}"
smoke_name="${project_name}-smoke"
persist_name="${project_name}-persist"
web_name="${project_name}-web"
alpine_image="alpine:3.20"
web_image="traefik/whoami:latest"

wait_running() {
  local name="$1"
  local i state
  for i in $(seq 1 20); do
    state=$(docker inspect -f '{{.State.Status}}' "$name" 2>/dev/null || true)
    if [[ "$state" == "running" ]]; then
      return 0
    fi
    sleep 1
  done
  echo "container_not_running=$name" >&2
  docker inspect -f 'state={{json .State}}' "$name" 2>/dev/null || true
  return 1
}

printf 'remote_exec=ok\n'
printf 'qualification=P1-02-runtime\n'
printf 'qualification_timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ ! -S "$HOME/.docker/run/docker.sock" ]]; then
  echo 'rootless_socket=missing' >&2
  exit 1
fi

docker info >/dev/null
docker network inspect "$network" >/dev/null
echo 'rootless_daemon=reachable'
echo 'provider_traefik_network=present'

# Remove only stale resources created by an earlier interrupted P1-02 attempt.
if [[ -f "$project_root/compose.yaml" ]]; then
  docker compose -p "$project_name" -f "$project_root/compose.yaml" down --remove-orphans >/dev/null 2>&1 || true
fi
docker rm -f "$smoke_name" "$persist_name" "$web_name" >/dev/null 2>&1 || true
rm -rf "$project_root"
mkdir -p "$data_dir"

if docker image inspect "$alpine_image" >/dev/null 2>&1; then
  pre_alpine=yes
else
  pre_alpine=no
fi
if docker image inspect "$web_image" >/dev/null 2>&1; then
  pre_web=yes
else
  pre_web=no
fi
cat > "$project_root/pre_images.env" <<EOF
pre_alpine=$pre_alpine
pre_web=$pre_web
EOF

printf 'preexisting_alpine_image=%s\n' "$pre_alpine"
printf 'preexisting_whoami_image=%s\n' "$pre_web"
echo 'docker_system_df_before_begin'
docker system df
echo 'docker_system_df_before_end'

smoke_out=$(docker run --rm --name "$smoke_name" "$alpine_image" sh -c 'printf byte-p1-02-smoke-ok')
if [[ "$smoke_out" != "byte-p1-02-smoke-ok" ]]; then
  echo 'container_smoke=fail' >&2
  exit 1
fi
echo 'container_smoke=pass'

# Reuse the provider-created route convention without storing or printing the
# tenant hostname. Existing managed containers already carry canonical Host()
# labels, so derive USER.SERVER.bysh.me from one of those labels.
user_lc=$(printf '%s' "$USER" | tr '[:upper:]' '[:lower:]')
existing_host=$(
  for id in $(docker ps -q); do
    docker inspect -f '{{range $k,$v := .Config.Labels}}{{printf "%s=%s\n" $k $v}}{{end}}' "$id" 2>/dev/null || true
  done \
    | grep -Eo '[A-Za-z0-9.-]+\.bysh\.me' \
    | tr '[:upper:]' '[:lower:]' \
    | grep -E "(^|\.)${user_lc}\.[^.]+\.bysh\.me$" \
    | head -n 1 \
    || true
)

public_base=$(
  printf '%s\n' "$existing_host" | awk -F. -v u="$user_lc" '
    {
      for (i=1; i<=NF; i++) {
        if ($i == u) {
          out=$i
          for (j=i+1; j<=NF; j++) out=out "." $j
          print out
          exit
        }
      }
    }
  '
)

if [[ -z "$public_base" || "$public_base" != *.bysh.me ]]; then
  echo 'managed_route_host_discovery=fail' >&2
  exit 1
fi
echo 'managed_route_host_discovery=pass'

route_slug="bytep102$(date -u +%H%M%S)${RANDOM}"
public_host="${route_slug}.${public_base}"
router_name="${route_slug}"
service_name="${route_slug}"

token="p1-02-$(date -u +%s)-${RANDOM}"
printf '%s\n' "$token" > "$data_dir/token.txt"
chmod 600 "$data_dir/token.txt"

cat > "$project_root/compose.yaml" <<EOF
services:
  persist:
    image: ${alpine_image}
    container_name: ${persist_name}
    restart: unless-stopped
    command: ["sh", "-c", "while :; do sleep 60; done"]
    volumes:
      - ./data:/data

  web:
    image: ${web_image}
    container_name: ${web_name}
    restart: unless-stopped
    networks:
      - proxy
    labels:
      - traefik.enable=true
      - traefik.http.routers.${router_name}.rule=Host(\`${public_host}\`)
      - traefik.http.routers.${router_name}.entrypoints=web
      - traefik.http.services.${service_name}.loadbalancer.server.port=80

networks:
  proxy:
    external: true
    name: ${network}
EOF

cd "$project_root"
docker compose -p "$project_name" config >/dev/null
echo 'compose_config=pass'

docker compose -p "$project_name" up -d persist >/dev/null
wait_running "$persist_name"
first_read=$(docker exec "$persist_name" cat /data/token.txt)
if [[ "$first_read" != "$token" ]]; then
  echo 'bind_mount_initial_read=fail' >&2
  exit 1
fi
echo 'bind_mount_initial_read=pass'

# Remove/recreate the container while leaving the host bind mount untouched.
docker compose -p "$project_name" rm -sf persist >/dev/null
docker compose -p "$project_name" up -d persist >/dev/null
wait_running "$persist_name"
second_read=$(docker exec "$persist_name" cat /data/token.txt)
if [[ "$second_read" != "$token" ]]; then
  echo 'bind_mount_persistence=fail' >&2
  exit 1
fi
echo 'bind_mount_persistence=pass'

restart_policy=$(docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' "$persist_name")
if [[ "$restart_policy" != "unless-stopped" ]]; then
  printf 'restart_policy=fail observed=%s\n' "$restart_policy" >&2
  exit 1
fi
docker restart "$persist_name" >/dev/null
wait_running "$persist_name"
third_read=$(docker exec "$persist_name" cat /data/token.txt)
if [[ "$third_read" != "$token" ]]; then
  echo 'restart_roundtrip=fail' >&2
  exit 1
fi
echo 'restart_policy=unless-stopped'
echo 'restart_roundtrip=pass'

docker compose -p "$project_name" up -d web >/dev/null
wait_running "$web_name"
if ! docker network inspect "$network" -f '{{range .Containers}}{{println .Name}}{{end}}' | grep -Fxq "$web_name"; then
  echo 'managed_route_network_membership=fail' >&2
  exit 1
fi
echo 'managed_route_network_membership=pass'

printf 'alpine_image_id=%s\n' "$(docker image inspect -f '{{.Id}}' "$alpine_image")"
printf 'whoami_image_id=%s\n' "$(docker image inspect -f '{{.Id}}' "$web_image")"
echo 'docker_system_df_after_setup_begin'
docker system df
echo 'docker_system_df_after_setup_end'

# The workflow captures and masks this exact line before displaying task output.
printf 'public_url=https://%s\n' "$public_host"
echo 'qualification_stage=ready_for_external_https'
