#!/bin/bash
# goodnight.sh — put this Mac to sleep: now, after a delay, or at a given time.
#
# Usage:
#   goodnight.sh              sleep in 15 seconds (grace period so an agent can finish its reply)
#   goodnight.sh 30m          sleep in 30 minutes (also: 90s, 2h, or a bare number = seconds)
#   goodnight.sh 23:30        sleep today at 23:30 (if already past — tomorrow)
#   goodnight.sh cancel       cancel a scheduled sleep
#   goodnight.sh status       check whether a sleep is scheduled
#
# No sudo required: forced sleep is allowed for the console user.
# Measured 2026-08-26 on Darwin 25.5.0: `pmset displaysleepnow` (same privileged
# path) exits 0 from a non-root sandboxed shell. Full `pmset sleepnow` is
# confirmed by its first real run.
#
# GOODNIGHT_CMD — overrides the sleep command (for dry-run tests).

set -u

# Fixed path on purpose: $TMPDIR differs between a sandboxed agent session and
# the user's own Terminal, and cancel/status must see the same schedule from both.
PIDFILE="/tmp/goodnight-sleep-$(id -u).pid"
SLEEP_CMD="${GOODNIGHT_CMD:-pmset sleepnow}"

case "${1:-}" in
  cancel)
    if [ -f "$PIDFILE" ] && kill "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Cancelled: scheduled sleep removed."
    else
      echo "Nothing scheduled."
    fi
    rm -f "$PIDFILE"
    exit 0
    ;;
  status)
    if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
      echo "Sleep scheduled (pid $(cat "$PIDFILE"))."
    else
      rm -f "$PIDFILE"
      echo "No sleep scheduled."
    fi
    exit 0
    ;;
  -h|--help|help)
    sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
esac

ARG="${1:-15s}"
now=$(date +%s)

if [[ "$ARG" =~ ^([0-9]+)([smh]?)$ ]]; then
  n="${BASH_REMATCH[1]}"; u="${BASH_REMATCH[2]:-s}"
  case "$u" in
    m) secs=$((n * 60)) ;;
    h) secs=$((n * 3600)) ;;
    *) secs=$n ;;
  esac
elif [[ "$ARG" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
  # BSD date: unspecified fields default to the current date => "today at HH:MM"
  target=$(date -j -f "%H:%M:%S" "${ARG}:00" +%s 2>/dev/null) || { echo "Invalid time: $ARG" >&2; exit 1; }
  [ "$target" -le "$now" ] && target=$((target + 86400))
  secs=$((target - now))
else
  echo "Unrecognized argument: $ARG (expected 30m / 90s / 2h / 23:30 / cancel / status)" >&2
  exit 1
fi

# A new schedule replaces the previous one
if [ -f "$PIDFILE" ]; then
  kill "$(cat "$PIDFILE")" 2>/dev/null
  rm -f "$PIDFILE"
fi

nohup /bin/bash -c "sleep $secs; rm -f '$PIDFILE'; $SLEEP_CMD" >/dev/null 2>&1 &
echo $! > "$PIDFILE"
disown

at_time=$(date -r $((now + secs)) "+%H:%M:%S")
echo "Mac will sleep at $at_time (in ${secs}s). Cancel with: \"$0\" cancel"
