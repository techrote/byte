#!/usr/bin/env bash
set -euo pipefail

# P1-02 trusted remote task: strictly read-only Docker discovery.
# The reusable qualifier is transferred alongside this task by repository CI.
# Re-probe after Bytesized Wsrelay installation activated rootless Docker.

printf 'remote_exec=ok\n'
printf 'qualification=P1-02-probe\n'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_tmp=$(cd -- "$script_dir/.." && pwd)

bash "$repo_tmp/tools/qualify_docker.sh" --phase probe
