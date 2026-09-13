#!/usr/bin/env bash
set -euo pipefail

# P1-01 active qualification phase. Fetch the exact reviewed helper from the
# immutable issue commit and run its bounded active phase in the workflow temp dir.
commit='1b1d53f994c534374474f5af73c8b85d94984711'
script_dir=$(cd "$(dirname "$0")" && pwd)
helper="$script_dir/qualify_sessions.sh"
url="https://raw.githubusercontent.com/techrote/byte/${commit}/tools/qualify_sessions.sh"

printf 'remote_exec=ok\n'
curl --fail --silent --show-error --location "$url" --output "$helper"
chmod 500 "$helper"
printf 'qualifier_source_commit=%s\n' "$commit"
bash "$helper" --phase active
printf 'remote_session_active=complete\n'
