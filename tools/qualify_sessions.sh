#!/usr/bin/env bash
set -euo pipefail

# P1-01 qualification helper. This script intentionally modifies only a dedicated
# temporary test directory and, during --phase active, a temporary crontab entry.
# The crontab is restored before the phase exits. No package installation occurs.

phase=""
while (($#)); do
  case "$1" in
    --phase)
      shift
      phase="${1:-}"
      ;;
    --help|-h)
      cat <<'EOF'
usage: qualify_sessions.sh --phase active|verify|ping

active  Test shell startup, foreground responsiveness, cron, user-systemd,
        existing tmux/screen, then launch a delayed nohup marker intended to
        survive SSH disconnect.
verify  Verify the delayed marker exists, then remove the dedicated test tree.
ping    Read-only timestamp/shell ping for additional connection/setup samples.
EOF
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      exit 2
      ;;
  esac
  shift
done

case "$phase" in
  active|verify|ping) ;;
  *)
    echo "--phase active|verify|ping is required" >&2
    exit 2
    ;;
esac

ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

test_root="$HOME/.byte-p1-01-test"

if [[ "$phase" == "ping" ]]; then
  printf 'qualification_ping_utc=%s\n' "$(ts)"
  printf 'shell=%s\n' "${SHELL:-unknown}"
  bash -lc 'printf "login_shell_ok=yes umask=%s\n" "$(umask)"'
  exit 0
fi

if [[ "$phase" == "verify" ]]; then
  printf 'verify_started_utc=%s\n' "$(ts)"
  if [[ ! -d "$test_root" ]]; then
    echo 'test_root=missing'
    exit 1
  fi
  if [[ -s "$test_root/nohup.marker" ]]; then
    printf 'disconnect_persistence=pass marker=%s\n' "$(cat "$test_root/nohup.marker")"
  else
    echo 'disconnect_persistence=fail marker=missing'
    rm -rf "$test_root"
    exit 1
  fi
  rm -rf "$test_root"
  echo 'cleanup=pass'
  printf 'verify_finished_utc=%s\n' "$(ts)"
  exit 0
fi

# active phase
printf 'active_started_utc=%s\n' "$(ts)"
if [[ -e "$test_root" ]]; then
  echo "refusing to overwrite existing test directory: $test_root" >&2
  exit 1
fi
mkdir -m 700 "$test_root"

cleanup_sessions() {
  if [[ -n "${tmux_session:-}" ]] && command -v tmux >/dev/null 2>&1; then
    tmux kill-session -t "$tmux_session" >/dev/null 2>&1 || true
  fi
  if [[ -n "${screen_session:-}" ]] && command -v screen >/dev/null 2>&1; then
    screen -S "$screen_session" -X quit >/dev/null 2>&1 || true
  fi
}
trap cleanup_sessions EXIT HUP INT TERM

printf '%s\n' '--- shell-startup-consistency ---'
for i in 1 2 3; do
  printf 'startup_%d=' "$i"
  bash -lc 'printf "shell=%s umask=%s\n" "${SHELL:-unknown}" "$(umask)"'
done

printf '%s\n' '--- foreground-responsiveness-with-background-job ---'
sleep 5 &
responsiveness_pid=$!
sleep 1
if kill -0 "$responsiveness_pid" 2>/dev/null && bash -lc ':'; then
  echo 'background_responsiveness=pass'
else
  echo 'background_responsiveness=fail'
fi
wait "$responsiveness_pid"

printf '%s\n' '--- cron ---'
if command -v crontab >/dev/null 2>&1; then
  original=$(mktemp)
  replacement=$(mktemp)
  had_original=0
  cron_modified=0
  if crontab -l >"$original" 2>/dev/null; then
    had_original=1
  else
    : >"$original"
  fi
  restore_cron() {
    if [[ "$cron_modified" -eq 1 ]]; then
      if [[ "$had_original" -eq 1 ]]; then
        crontab "$original" >/dev/null 2>&1 || true
      else
        crontab -r >/dev/null 2>&1 || true
      fi
      cron_modified=0
    fi
    rm -f "$original" "$replacement"
  }
  trap 'restore_cron; cleanup_sessions' EXIT HUP INT TERM

  cat "$original" >"$replacement"
  printf '%s\n' '# byte P1-01 temporary qualification entry' >>"$replacement"
  printf '%s\n' '* * * * * /bin/sh -c '\''printf cron-ok > "$HOME/.byte-p1-01-test/cron.marker"'\''' >>"$replacement"
  if crontab "$replacement"; then
    cron_modified=1
    cron_result=timeout
    for _ in $(seq 1 80); do
      if [[ -s "$test_root/cron.marker" ]]; then
        cron_result=pass
        break
      fi
      sleep 1
    done
    printf 'cron_test=%s\n' "$cron_result"
  else
    echo 'cron_test=install-error'
  fi
  restore_cron
  trap cleanup_sessions EXIT HUP INT TERM
else
  echo 'cron_test=missing'
fi

printf '%s\n' '--- user-systemd ---'
if command -v systemctl >/dev/null 2>&1; then
  set +e
  systemd_text=$(systemctl --user is-system-running 2>&1)
  systemd_rc=$?
  set -e
  printf 'systemd_user_rc=%d\n' "$systemd_rc"
  printf 'systemd_user_summary=%s\n' "$(printf '%s\n' "$systemd_text" | head -n 1)"
  if [[ "$systemd_rc" -eq 0 ]] && command -v systemd-run >/dev/null 2>&1; then
    if systemd-run --user --wait --collect --unit="byte-p101-$$" /bin/true >/dev/null 2>&1; then
      echo 'systemd_transient_test=pass'
    else
      echo 'systemd_transient_test=error'
    fi
  else
    echo 'systemd_transient_test=unavailable'
  fi
else
  echo 'systemd_user=missing'
fi

printf '%s\n' '--- existing-session-supervisors ---'
if command -v tmux >/dev/null 2>&1; then
  tmux_session="byte-p101-$$"
  rm -f "$test_root/tmux.marker"
  if tmux new-session -d -s "$tmux_session" "sleep 2; printf tmux-ok > '$test_root/tmux.marker'" >/dev/null 2>&1; then
    sleep 4
    if [[ -s "$test_root/tmux.marker" ]]; then
      echo 'tmux_test=pass'
    else
      echo 'tmux_test=marker-missing'
    fi
  else
    echo 'tmux_test=start-error'
  fi
  tmux kill-session -t "$tmux_session" >/dev/null 2>&1 || true
  tmux_session=""
else
  echo 'tmux_test=missing'
fi

if command -v screen >/dev/null 2>&1; then
  screen_session="byte-p101-$$"
  rm -f "$test_root/screen.marker"
  if screen -dmS "$screen_session" bash -lc "sleep 2; printf screen-ok > '$test_root/screen.marker'" >/dev/null 2>&1; then
    sleep 4
    if [[ -s "$test_root/screen.marker" ]]; then
      echo 'screen_test=pass'
    else
      echo 'screen_test=marker-missing'
    fi
  else
    echo 'screen_test=start-error'
  fi
  screen -S "$screen_session" -X quit >/dev/null 2>&1 || true
  screen_session=""
else
  echo 'screen_test=missing'
fi

printf '%s\n' '--- disconnect-persistence-setup ---'
rm -f "$test_root/nohup.marker" "$test_root/nohup.log"
nohup bash -lc "sleep 5; printf 'nohup-ok %s\\n' \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" > '$test_root/nohup.marker'" \
  </dev/null >"$test_root/nohup.log" 2>&1 &
printf 'nohup_started_pid=%d\n' "$!"
printf 'active_finished_utc=%s\n' "$(ts)"
echo 'next_phase=verify_after_disconnect'
