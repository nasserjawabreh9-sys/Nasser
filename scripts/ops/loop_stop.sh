#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
PIDFILE="$ROOT/station_meta/queue/dynamo_worker.pid"
if [ ! -f "$PIDFILE" ]; then
  echo "OK: no pidfile"
  exit 0
fi
PID="$(cat "$PIDFILE" || true)"
if [ -n "$PID" ]; then
  kill "$PID" >/dev/null 2>&1 || true
fi
rm -f "$PIDFILE"
echo "OK: stopped"
