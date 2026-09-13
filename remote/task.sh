#!/usr/bin/env bash
set -euo pipefail

# P0-03 fixed live acceptance task. Fetch the exact reviewed doctor from
# immutable commit 58d0a3a62c183b3326c7d66fbf4ced1c0a0a9755 into the workflow-created
# temporary directory and run it read-only.
commit='58d0a3a62c183b3326c7d66fbf4ced1c0a0a9755'
script_dir=$(cd "$(dirname "$0")" && pwd)
doctor="$script_dir/appbox_doctor.py"
url="https://raw.githubusercontent.com/techrote/byte/${commit}/tools/appbox_doctor.py"

printf 'remote_exec=ok\n'
curl --fail --silent --show-error --location "$url" --output "$doctor"
chmod 500 "$doctor"
printf 'doctor_source_commit=%s\n' "$commit"
python3 "$doctor" --require quota --require tool:git
printf '%s\n' '--- docker-required-negative-check ---'
if python3 "$doctor" --require docker:daemon; then
  echo 'docker_required_unexpected_pass'
  exit 1
else
  rc=$?
  test "$rc" -eq 2
  echo 'docker_required_expected_fail=ok'
fi
printf '%s\n' '--- doctor-json ---'
python3 "$doctor" --json --require quota --require tool:git
printf 'remote_doctor=complete\n'
