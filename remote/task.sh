#!/usr/bin/env bash
set -euo pipefail

# P0-03 live acceptance task. Fetch the exact reviewed doctor from immutable
# commit 52462fe3b513a4d798d9e46cb22f9d0db5065a30, run read-only requirements,
# then rely on the enclosing remote lane to discard the temporary directory.
commit='52462fe3b513a4d798d9e46cb22f9d0db5065a30'
doctor='./appbox_doctor.py'
url="https://raw.githubusercontent.com/techrote/byte/${commit}/tools/appbox_doctor.py"

printf 'remote_exec=ok\n'
curl --fail --silent --show-error --location "$url" --output "$doctor"
chmod 500 "$doctor"
printf 'doctor_source_commit=%s\n' "$commit"
python3 "$doctor" --require quota --require tool:git
printf '%s\n' '--- doctor-json ---'
python3 "$doctor" --json --require quota --require tool:git
printf 'remote_doctor=complete\n'
