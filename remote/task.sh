#!/usr/bin/env bash
set -euo pipefail

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
        print("container={}".format(name))
        print("image={}".format(image))
        print("restart_policy={}".format(restart))
        print("exposed_ports={}".format(",".join(exposed)))
        for hp, cp, hip in sorted(matches):
            print("binding=host:{}->container:{};host_ip={}".format(hp, cp, hip or "unspecified"))
'
printf 'container_mapping_end\n'

printf 'traefik_runtime_config_begin\n'
docker inspect traefik | python3 -c '
import json, sys
c=json.load(sys.stdin)[0]
cmd=c.get("Config",{}).get("Cmd") or []
for arg in cmd:
    low=arg.lower()
    if any(key in low for key in ("entrypoint", "api", "dashboard", "ping", "metrics", "provider", "address")):
        print("cmd_arg={}".format(arg))
'
printf 'traefik_runtime_config_end\n'

printf 'wsrelay_route_policy_begin\n'
docker inspect wsrelay | python3 -c '
import json,re,sys
c=json.load(sys.stdin)[0]
labels=c.get("Config",{}).get("Labels") or {}
router={k:v for k,v in labels.items() if k.startswith("traefik.http.routers.")}
service={k:v for k,v in labels.items() if k.startswith("traefik.http.services.")}
middleware={k:v for k,v in labels.items() if k.startswith("traefik.http.middlewares.")}
print("traefik_enabled={}".format(labels.get("traefik.enable")))
rules=[v for k,v in router.items() if k.endswith(".rule")]
print("router_rule_present={}".format("yes" if rules else "no"))
for rule in rules:
    redacted=re.sub(r"(?i)(Host|HostRegexp)\(([^)]*)\)", lambda m: m.group(1)+"(<host>)", rule)
    print("router_rule_shape={}".format(redacted))
print("router_entrypoints={}".format(",".join(sorted({v for k,v in router.items() if k.endswith(".entrypoints")})) or "unspecified"))
print("router_middlewares_present={}".format("yes" if any(k.endswith(".middlewares") for k in router) else "no"))
print("router_middleware_refs_count={}".format(sum(len(v.split(",")) for k,v in router.items() if k.endswith(".middlewares"))))
print("middleware_config_keys={}".format(",".join(sorted(k.rsplit(".",1)[-1] for k in middleware)) or "none"))
print("service_port_values={}".format(",".join(sorted({v for k,v in service.items() if k.endswith(".loadbalancer.server.port")})) or "unspecified"))
'
route_host=$(docker inspect wsrelay | python3 -c '
import json,re,sys
labels=json.load(sys.stdin)[0].get("Config",{}).get("Labels") or {}
for k,rule in labels.items():
    if k.startswith("traefik.http.routers.") and k.endswith(".rule"):
        m=re.search(r"(?i)Host(?:Regexp)?\(\s*[`\"]([^`\"]+)[`\"]\s*\)", rule)
        if m:
            print(m.group(1)); break
')
if [[ -n "$route_host" ]]; then
  set +e
  routed=$(curl --silent --output /dev/null --connect-timeout 2 --max-time 3 \
    -H "Host: $route_host" \
    --write-out 'http=%{http_code};bytes=%{size_download};redirect=%{redirect_url};total=%{time_total}' \
    "http://127.0.0.1:37586/" 2>/dev/null)
  routed_rc=$?
  set -e
  # Do not emit redirect_url because it may contain the private tenant hostname.
  routed_safe=$(printf '%s' "$routed" | sed -E 's#;redirect=[^;]*#;redirect=<redacted>#')
  printf 'raw_web_with_app_host=rc:%s;%s\n' "$routed_rc" "$routed_safe"
else
  echo 'raw_web_with_app_host=not_tested_no_extractable_host_rule'
fi
printf 'wsrelay_route_policy_end\n'

printf 'listener_snapshot_begin\n'
ss -ltnp 2>&1 | grep -E ':(18214|37586)([[:space:]]|$)' \
  | sed -e "s#${HOME//\#/\\#}#<HOME>#g" -e "s#${USER:-__NO_USER__}#<USER>#g" || true
printf 'listener_snapshot_end\n'

for port in "${target_ports[@]}"; do
  printf 'local_tcp_%s=' "$port"
  if timeout 3 bash -c "</dev/tcp/127.0.0.1/$port" 2>/dev/null; then echo open; else echo closed_or_filtered; fi
  for path in "${probe_paths[@]}"; do
    set +e
    metrics=$(curl --silent --output /dev/null --connect-timeout 2 --max-time 3 \
      --write-out 'http=%{http_code};total=%{time_total}' "http://127.0.0.1:$port$path" 2>/dev/null)
    rc=$?
    set -e
    printf 'local_http_%s%s=rc:%s;%s\n' "$port" "$path" "$rc" "$metrics"
  done
done

printf 'audit_complete=yes\n'
