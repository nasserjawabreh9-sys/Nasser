#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
cd "$ROOT"

PIDFILE="station_meta/queue/dynamo_worker.pid"
LOGFILE="station_meta/logs/dynamo_worker.log"

# kill stale if exists
if [ -f "$PIDFILE" ]; then
  OLD="$(cat "$PIDFILE" || true)"
  if [ -n "$OLD" ]; then
    kill "$OLD" >/dev/null 2>&1 || true
  fi
  rm -f "$PIDFILE"
fi

cd "$ROOT/backend"
source .venv/bin/activate

nohup python - <<'PY' >> "../$LOGFILE" 2>&1 &
from app.loop_worker import daemon_loop
daemon_loop(interval_sec=2.0)
PY

echo $! > "../$PIDFILE"
echo "OK: dynamo_worker started pid=$(cat ../$PIDFILE)"
echo "LOG: $LOGFILE"
