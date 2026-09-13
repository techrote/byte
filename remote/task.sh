#!/usr/bin/env bash
set -euo pipefail

# P1-03 trusted remote task. The qualifier is self-bounded, quota-guarded and
# cleans its disposable home-directory test tree on both success and failure.

printf 'remote_exec=ok\n'
printf 'qualification=P1-03-storage\n'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_tmp=$(cd -- "$script_dir/.." && pwd)

bash "$repo_tmp/tools/qualify_storage.sh"
