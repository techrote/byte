#!/usr/bin/env bash
set -euo pipefail

# P1-04 post-run verification: confirm the bounded network probe left no
# disposable payload directory in the Appbox home directory.

printf 'remote_exec=ok\n'
printf 'qualification=P1-04-network-verify\n'
printf 'verified_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if compgen -G "$HOME/.byte-p1-04-test.*" >/dev/null; then
  echo 'disposable_test_tree_present=yes'
  echo 'cleanup_verify=fail'
  exit 5
fi

echo 'disposable_test_tree_present=no'
echo 'cleanup_verify=pass'
