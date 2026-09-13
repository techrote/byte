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
run_capture docker_default_info docker info --format 'server={{.ServerVersion}} rootless={{json .SecurityOptions}}'

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
  set +e
  explicit_info=$(DOCKER_HOST="unix://$rootless_socket" docker info --format 'server={{.ServerVersion}} rootless={{json .SecurityOptions}}' 2>&1)
  explicit_rc=$?
  set -e
  printf 'docker_rootless_info_rc=%d\n' "$explicit_rc"
  printf 'docker_rootless_info=%s\n' "$(printf '%s' "$explicit_info" | redact | head -n 1)"
  if [[ "$explicit_rc" -eq 0 ]] && [[ "$explicit_info" != *"permission denied"* ]]; then
    explicit_ok=1
  fi
else
  echo 'docker_rootless_info_rc=socket-absent'
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

echo 'probe_complete=yes'
