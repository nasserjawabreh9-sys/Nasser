#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${ROOT:-$HOME/station_root}"
cd "$ROOT"

# load env if exists
[ -f "$HOME/station_env.sh" ] && source "$HOME/station_env.sh" || true

PORT="${PORT:-8000}"
HOST="${HOST:-127.0.0.1}"   # local safe default
LOG="station_logs/backend.log"
PIDFILE="station_logs/backend.pid"

mkdir -p station_logs

start_backend() {
  echo ">>> [GUARD] starting backend on ${HOST}:${PORT}"
  # Adjust module path if your uvicorn entry differs
  nohup ./.venv/bin/uvicorn app.main:app --host "$HOST" --port "$PORT" >"$LOG" 2>&1 &
  echo $! > "$PIDFILE"
}

is_healthy() {
  curl -s "http://${HOST}:${PORT}/health" >/dev/null 2>&1
}

while true; do
  if [ -f "$PIDFILE" ]; then
    PID="$(cat "$PIDFILE" || true)"
    if [ -n "${PID:-}" ] && kill -0 "$PID" >/dev/null 2>&1; then
      if is_healthy; then
        sleep 5
        continue
      fi
    fi
  fi

  echo ">>> [GUARD] backend not healthy -> restart"
  # try kill old pid
  if [ -f "$PIDFILE" ]; then
    PID="$(cat "$PIDFILE" || true)"
    [ -n "${PID:-}" ] && kill "$PID" >/dev/null 2>&1 || true
  fi

  start_backend
  sleep 3
done
