#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
PIDFILE="$ROOT/station_meta/queue/dynamo_worker.pid"
if [ ! -f "$PIDFILE" ]; then
  echo "STATUS: stopped"
  exit 0
fi
PID="$(cat "$PIDFILE" || true)"
if [ -z "$PID" ]; then
  echo "STATUS: stopped (empty pidfile)"
  exit 0
fi
if kill -0 "$PID" >/dev/null 2>&1; then
  echo "STATUS: running pid=$PID"
else
  echo "STATUS: stale pidfile (pid not running)"
fi
