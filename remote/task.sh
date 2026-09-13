#!/usr/bin/env bash
set -euo pipefail

# P1-01 read-only connection/setup sample using the exact reviewed helper.
commit='1b1d53f994c534374474f5af73c8b85d94984711'
script_dir=$(cd "$(dirname "$0")" && pwd)
helper="$script_dir/qualify_sessions.sh"
url="https://raw.githubusercontent.com/techrote/byte/${commit}/tools/qualify_sessions.sh"

printf 'remote_exec=ok\n'
curl --fail --silent --show-error --location "$url" --output "$helper"
chmod 500 "$helper"
printf 'qualifier_source_commit=%s\n' "$commit"
bash "$helper" --phase ping
printf 'remote_session_ping=complete\n'
