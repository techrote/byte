#!/usr/bin/env bash
set -euo pipefail

# P0-02 execution task: run the version-controlled read-only tenant inventory.
root=$(cd "$(dirname "$0")/.." && pwd)
printf 'remote_exec=ok\n'
bash "$root/tools/appbox_probe.sh"
printf 'remote_inventory=complete\n'
