#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
BE="$ROOT/backend"
FE="$ROOT/frontend"

BE_PORT="${BE_PORT:-8000}"
FE_PORT="${FE_PORT:-5173}"
HOST="0.0.0.0"
URL_BE="http://127.0.0.1:$BE_PORT"
URL_FE="http://127.0.0.1:$FE_PORT"
EDIT="${STATION_EDIT_KEY:-1234}"

mkdir -p "$ROOT/station_logs"

echo "=== [NUKE] Kill old servers ==="
pkill -f "uvicorn" || true
pkill -f "vite" || true
pkill -f "npm run preview" || true
sleep 1

echo "=== [NUKE] Backend start ==="
cd "$BE"
if [ -f .venv/bin/activate ]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

export HOST="$HOST"
export PORT="$BE_PORT"
export TARGET="${TARGET:-main:app}"

nohup python -m uvicorn "$TARGET" --host "$HOST" --port "$PORT" \
  > "$ROOT/station_logs/backend.log" 2>&1 &

sleep 2

echo "=== [NUKE] Frontend preview ==="
cd "$FE"
export VITE_BACKEND_URL="$URL_BE"
if [ ! -d "dist" ]; then
  npm run build
fi

nohup npm run preview -- --host "$HOST" --port "$FE_PORT" \
  > "$ROOT/station_logs/frontend.log" 2>&1 &

sleep 2

echo "=== [SMOKE] health/info/version ==="
curl -s "$URL_BE/health"; echo
curl -s "$URL_BE/info" || true; echo
curl -s "$URL_BE/version" || true; echo

echo "=== [SMOKE] ops git status (should be JSON) ==="
curl -s -X POST "$URL_BE/ops/git/status" -H "x-edit-key: $EDIT" -H "Content-Type: application/json" -d '{}' || true
echo

echo "=== [OPEN] Station ==="
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "$URL_FE"
else
  echo "Open manually: $URL_FE"
fi

echo
echo "===================================="
echo " Station is UP"
echo " Backend : $URL_BE"
echo " Frontend: $URL_FE"
echo " Logs:"
echo "   - $ROOT/station_logs/backend.log"
echo "   - $ROOT/station_logs/frontend.log"
echo "===================================="
