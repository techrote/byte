#!/usr/bin/env bash
set -euo pipefail

# P1-02 rootless-Docker qualification helper.
# `probe` is strictly read-only and intentionally checks both the default Docker
# endpoint and Bytesized's documented per-user rootless socket.

phase="probe"
while (($#)); do
  case "$1" in
    --phase)
      shift
      phase="${1:-}"
      ;;
    --help|-h)
      cat <<'EOF'
usage: qualify_docker.sh [--phase probe]

probe  Read-only discovery of Docker client, Compose, rootless socket/context,
       provider Traefik network and current Docker disk use.
EOF
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

if [[ "$phase" != "probe" ]]; then
  echo "unsupported phase: $phase" >&2
  exit 2
fi

redact() {
  sed \
    -e "s#${HOME//\#/\\#}#<HOME>#g" \
    -e "s#${USER:-__NO_USER__}#<USER>#g"
}

run_capture() {
  local label="$1"
  shift
  local out rc
  set +e
  out=$("$@" 2>&1)
  rc=$?
  set -e
  printf '%s_rc=%d\n' "$label" "$rc"
  if [[ -n "$out" ]]; then
    printf '%s_output_begin\n' "$label"
    printf '%s\n' "$out" | redact | head -n 80
    printf '%s_output_end\n' "$label"
  fi
  return 0
}

docker_info_probe() {
  local label="$1"
  shift
  local out rc reachable=yes
  set +e
  out=$("$@" 2>&1)
  rc=$?
  set -e

  # Docker 24 on the current Appbox can print a socket permission error while
  # returning rc=0 for a formatted `docker info`. Treat common daemon/socket
  # diagnostics as failure even when the process exit status is misleading.
  if [[ "$rc" -ne 0 ]] || grep -Eqi \
      'permission denied|cannot connect to the docker daemon|is the docker daemon running|error during connect|dial unix .*: connect:' \
      <<<"$out"; then
    reachable=no
  fi

  printf '%s_rc=%d\n' "$label" "$rc"
  printf '%s_reachable=%s\n' "$label" "$reachable"
  if [[ -n "$out" ]]; then
    printf '%s_output_begin\n' "$label"
    printf '%s\n' "$out" | redact | head -n 80
    printf '%s_output_end\n' "$label"
  fi

  [[ "$reachable" == yes ]]
}

printf 'probe_timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'docker_host_env_set=%s\n' "$([[ -n "${DOCKER_HOST:-}" ]] && echo yes || echo no)"

if ! command -v docker >/dev/null 2>&1; then
  echo 'docker_client=missing'
  exit 0
fi

echo 'docker_client=present'
run_capture docker_client_version docker --version
run_capture docker_compose_version docker compose version
run_capture docker_context_show docker context show

if docker_info_probe docker_default_info docker info --format 'server={{.ServerVersion}} rootless={{json .SecurityOptions}}'; then
  default_ok=1
else
  default_ok=0
fi

rootless_socket="$HOME/.docker/run/docker.sock"
if [[ -S "$rootless_socket" ]]; then
  echo 'rootless_socket=socket'
  stat -c 'rootless_socket_mode=%a owner_uid=%u owner_gid=%g size=%s' "$rootless_socket" 2>/dev/null || true
elif [[ -e "$rootless_socket" ]]; then
  echo 'rootless_socket=present_not_socket'
  stat -c 'rootless_socket_mode=%a owner_uid=%u owner_gid=%g size=%s type=%F' "$rootless_socket" 2>/dev/null || true
else
  echo 'rootless_socket=absent'
fi

explicit_ok=0
if [[ -S "$rootless_socket" ]]; then
  if docker_info_probe docker_rootless_info env DOCKER_HOST="unix://$rootless_socket" docker info --format 'server={{.ServerVersion}} rootless={{json .SecurityOptions}}'; then
    explicit_ok=1
  fi
else
  echo 'docker_rootless_info_rc=socket-absent'
  echo 'docker_rootless_info_reachable=no'
fi

if [[ "$explicit_ok" -eq 1 ]]; then
  echo 'rootless_daemon=reachable'
  if DOCKER_HOST="unix://$rootless_socket" docker network inspect "traefik_${USER}" >/dev/null 2>&1; then
    echo 'provider_traefik_network=present'
  else
    echo 'provider_traefik_network=absent'
  fi
  echo 'docker_disk_usage_begin'
  DOCKER_HOST="unix://$rootless_socket" docker system df 2>&1 | redact | head -n 40 || true
  echo 'docker_disk_usage_end'
else
  echo 'rootless_daemon=unreachable'
  echo 'provider_traefik_network=not_checked'
fi

if [[ "$default_ok" -eq 0 && "$explicit_ok" -eq 0 ]]; then
  echo 'activation_state=provider_rootless_docker_not_initialized_or_not_exposed'
fi

echo 'probe_complete=yes'
