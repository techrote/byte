#!/usr/bin/env bash
set -euo pipefail

# P1-04 trusted remote task. The qualifier is single-stream, traffic-bounded and
# cleans its temporary upload payload on success or failure.

printf 'remote_exec=ok\n'
printf 'qualification=P1-04-network\n'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_tmp=$(cd -- "$script_dir/.." && pwd)

bash "$repo_tmp/tools/qualify_network.sh"
