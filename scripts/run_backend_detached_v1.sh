#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
LOGD="$ROOT/station_logs"
mkdir -p "$LOGD"

# keep CPU awake (if available)
command -v termux-wake-lock >/dev/null 2>&1 && termux-wake-lock || true

pkill -f "uvicorn" >/dev/null 2>&1 || true
sleep 1

cd "$ROOT/backend"
ts="$(date -u +%Y%m%d_%H%M%S)"
log="$LOGD/backend_${ts}.log"

nohup ./run_backend_official.sh > "$log" 2>&1 &
echo $! > "$LOGD/backend.pid"

sleep 1
echo "PID=$(cat "$LOGD/backend.pid")"
echo "LOG=$log"
echo "CHECK:"
echo "  curl -s http://127.0.0.1:8000/health ; echo"
echo "  curl -s http://127.0.0.1:8000/uul/factory/status?tail=30 | head"
