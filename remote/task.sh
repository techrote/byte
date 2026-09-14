#!/usr/bin/env bash
set -euo pipefail

# P1-05 trusted remote task: install the bounded, self-expiring 48-hour sampler
# and take the first live observation immediately.

printf 'remote_exec=ok\n'
printf 'qualification=P1-05-install\n'
printf 'install_timestamp_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_tmp=$(cd -- "$script_dir/.." && pwd)

bash "$repo_tmp/tools/sample_contention.sh" --install 48

echo 'status_after_install_begin'
bash "$HOME/.byte-p1-05/bin/sample_contention.sh" --status
echo 'status_after_install_end'
