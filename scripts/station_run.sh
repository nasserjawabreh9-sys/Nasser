#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[STATION] Unified run starting (ports 8800 / 5180)..."

# Load env
if [ -f "$HOME/station_env.sh" ]; then
  . "$HOME/station_env.sh"
  echo "[STATION] station_env.sh loaded."
else
  echo "[STATION] WARNING: station_env.sh not found. Continuing without it..."
fi

# Kill any previous runs (best-effort)
pkill -f "uvicorn app.main:app" 2>/dev/null || true
pkill -f "npm run dev" 2>/dev/null || true

BACKEND_PORT=8800
FRONTEND_PORT=5180

# Start backend
cd "$HOME/station_root/backend"

if [ ! -d ".venv" ]; then
  echo "[STATION] ERROR: .venv not found. Run station_build.sh first."
  exit 1
fi

. .venv/bin/activate

echo "[STATION] Starting backend on 0.0.0.0:${BACKEND_PORT} ..."
uvicorn app.main:app --host 0.0.0.0 --port ${BACKEND_PORT} --reload &
BACKEND_PID=$!

# Start frontend dev server
cd "$HOME/station_root/frontend"

# Backend URL for frontend
export VITE_STATION_BACKEND_URL="http://127.0.0.1:${BACKEND_PORT}"

echo "[STATION] Starting frontend dev server on 0.0.0.0:${FRONTEND_PORT} ..."
npm run dev -- --host 0.0.0.0 --port ${FRONTEND_PORT} &
FRONTEND_PID=$!

echo "-----------------------------------------"
echo "STATION Backend:  http://127.0.0.1:${BACKEND_PORT}/health"
echo "STATION Config:   http://127.0.0.1:${BACKEND_PORT}/config"
echo "STATION UI:       http://127.0.0.1:${FRONTEND_PORT}/"
echo "-----------------------------------------"
echo "Use:  termux-open-url http://127.0.0.1:${FRONTEND_PORT}/"
echo "Press Ctrl+C here to stop both backend and frontend."
echo "-----------------------------------------"

wait $BACKEND_PID $FRONTEND_PID
