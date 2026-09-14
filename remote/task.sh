#!/usr/bin/env bash
set -euo pipefail

# Read-only audit of the two rootless Docker host-port mappings seen in the
# Bytesized process view. No container, route, listener, or config is changed.

export DOCKER_HOST="unix://$HOME/.docker/run/docker.sock"
target_ports=(18214 37586)
probe_paths=(/ /dashboard/ /api/overview /api/rawdata /ping /metrics)

printf 'remote_exec=ok\n'
printf 'audit=rootless-port-mappings\n'
printf 'timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

docker info --format 'docker_server={{.ServerVersion}}' >/dev/null
printf 'docker_rootless_reachable=yes\n'

printf 'container_mapping_begin\n'
docker inspect $(docker ps -q) | python3 -c '
import json, sys
ports={"18214","37586"}
for c in json.load(sys.stdin):
    name=c.get("Name","").lstrip("/")
    image=c.get("Config",{}).get("Image")
    bindings=c.get("HostConfig",{}).get("PortBindings") or {}
    matches=[]
    for container_port, rows in bindings.items():
        for row in rows or []:
            hp=str(row.get("HostPort", ""))
            if hp in ports:
                matches.append((hp, container_port, row.get("HostIp", "")))
    if matches:
        restart=(c.get("HostConfig",{}).get("RestartPolicy") or {}).get("Name")
        exposed=sorted((c.get("Config",{}).get("ExposedPorts") or {}).keys())
        labels=c.get("Config",{}).get("Labels") or {}
        traefik_enabled=labels.get("traefik.enable")
        print("container={}".format(name))
        print("image={}".format(image))
        print("restart_policy={}".format(restart))
        print("exposed_ports={}".format(",".join(exposed)))
        print("traefik_enable={}".format(traefik_enabled))
        for hp, cp, hip in sorted(matches):
            print("binding=host:{}->container:{};host_ip={}".format(hp, cp, hip or "unspecified"))
'
printf 'container_mapping_end\n'

printf 'traefik_runtime_config_begin\n'
docker inspect traefik | python3 -c '
import json, sys
c=json.load(sys.stdin)[0]
entry=c.get("Config",{}).get("Entrypoint") or []
cmd=c.get("Config",{}).get("Cmd") or []
print("entrypoint={}".format(" ".join(entry)))
for arg in cmd:
    low=arg.lower()
    if any(key in low for key in ("entrypoint", "api", "dashboard", "ping", "metrics", "provider", "address")):
        print("cmd_arg={}".format(arg))
'
printf 'traefik_runtime_config_end\n'

printf 'listener_snapshot_begin\n'
if command -v ss >/dev/null 2>&1; then
  ss -ltnp 2>&1 | grep -E ':(18214|37586)([[:space:]]|$)' \
    | sed -e "s#${HOME//\#/\\#}#<HOME>#g" -e "s#${USER:-__NO_USER__}#<USER>#g" || true
else
  echo 'ss=unavailable'
fi
printf 'listener_snapshot_end\n'

for port in "${target_ports[@]}"; do
  printf 'local_tcp_%s=' "$port"
  if timeout 3 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then
    echo open
  else
    echo closed_or_filtered
  fi

  for path in "${probe_paths[@]}"; do
    set +e
    metrics=$(curl --silent --show-error --output /dev/null \
      --connect-timeout 2 --max-time 3 \
      --write-out 'http=%{http_code};total=%{time_total}' \
      "http://127.0.0.1:$port$path" 2>/dev/null)
    rc=$?
    set -e
    safe_path=${path//\//_}
    [[ -n "$safe_path" ]] || safe_path=root
    printf 'local_http_%s%s=rc:%s;%s\n' "$port" "$path" "$rc" "$metrics"
  done
done

printf 'audit_complete=yes\n'
