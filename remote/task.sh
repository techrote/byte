#!/usr/bin/env bash
set -euo pipefail

# P1-03 post-run verification task: read-only quota snapshot plus explicit
# confirmation that the active qualifier left no marker or disposable tree.

printf 'remote_exec=ok\n'
printf 'qualification=P1-03-storage-verify\n'

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_tmp=$(cd -- "$script_dir/.." && pwd)

bash "$repo_tmp/tools/qualify_storage.sh" --phase verify
