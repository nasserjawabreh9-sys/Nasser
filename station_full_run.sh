#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
BACKEND_DIR="$ROOT/backend"
FRONTEND_DIR="$ROOT/frontend"
ENV_FILE="$HOME/station_env.sh"

echo ">>> [STATION] Starting full Station (backend + frontend)..."

# Load environment (API keys, etc.) if exists
if [ -f "$ENV_FILE" ]; then
  . "$ENV_FILE"
  echo ">>> [STATION] Environment loaded from $ENV_FILE"
else
  echo ">>> [STATION] WARNING: $ENV_FILE not found, continuing without extra env."
fi

# Kill any old processes
pkill -f "uvicorn app.main:app" 2>/dev/null || true
pkill -f "node.*vite" 2>/dev/null || true

# ----- Backend -----
cd "$BACKEND_DIR"

if [ ! -d ".venv" ]; then
  echo ">>> [STATION] ERROR: .venv not found in backend. Please create it first."
  echo "    Example:"
  echo "    cd $BACKEND_DIR"
  echo "    python -m venv .venv"
  echo "    source .venv/bin/activate"
  echo "    pip install -r requirements.txt"
  exit 1
fi

# shellcheck disable=SC1091
source .venv/bin/activate

echo ">>> [STATION] Starting backend on port 8000..."
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > "$ROOT/backend.log" 2>&1 &

# Small wait so backend can boot
sleep 2

# ----- Frontend -----
cd "$FRONTEND_DIR"

if [ ! -d "node_modules" ]; then
  echo ">>> [STATION] Installing frontend dependencies (npm install)..."
  npm install
fi

echo ">>> [STATION] Starting frontend (Vite) on port 5173..."
nohup npm run dev -- --host 0.0.0.0 --port 5173 > "$ROOT/frontend.log" 2>&1 &

echo ">>> [STATION] All services started."
echo ">>> Backend health:  curl http://127.0.0.1:8000/health"
echo ">>> Frontend URL:    http://127.0.0.1:5173/"
echo ">>> To open in browser on Android:"
echo "termux-open-url http://127.0.0.1:5173/"
echo ">>> Logs:"
echo "tail -f $ROOT/backend.log"
echo "tail -f $ROOT/frontend.log"
#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
BACKEND_DIR="$ROOT/backend"
FRONTEND_DIR="$ROOT/frontend"
ENV_FILE="$HOME/station_env.sh"

echo ">>> [STATION] Starting full Station (backend + frontend)..."

# ===== 1) Load environment (API keys, etc.) =====
if [ -f "$ENV_FILE" ]; then
  . "$ENV_FILE"
  echo ">>> [STATION] Environment loaded from $ENV_FILE"
else
  echo ">>> [STATION] WARNING: $ENV_FILE not found, continuing without extra env."
fi

# ===== 2) Kill any old Station processes =====
pkill -f "uvicorn app.main:app" 2>/dev/null || true
pkill -f "node.*vite" 2>/dev/null || true

# ===== 3) Backend (Starlette + Uvicorn) =====
cd "$BACKEND_DIR"

if [ ! -d ".venv" ]; then
  echo ">>> [STATION] Backend venv not found, creating and installing deps..."
  python -m venv .venv
  # shellcheck disable=SC1091
  source .venv/bin/activate
  pip install --upgrade pip
  pip install -r requirements.txt
else
  echo ">>> [STATION] Activating backend venv..."
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

echo ">>> [STATION] Starting backend on port 8000..."
nohup uvicorn app.main:app --host 0.0.0.0 --port 8000 > "$ROOT/backend.log" 2>&1 &

# أعطِ الباك إند ثانية يشتغل
sleep 2

# ===== 4) Frontend (Vite React) =====
cd "$FRONTEND_DIR"

if [ ! -d "node_modules" ]; then
  echo ">>> [STATION] node_modules not found, running npm install (first time only)..."
  npm install
fi

echo ">>> [STATION] Starting frontend (Vite) on port 5173..."
nohup npm run dev -- --host 0.0.0.0 --port 5173 > "$ROOT/frontend.log" 2>&1 &

# ===== 5) Summary =====
echo ">>> [STATION] All services started."
echo ">>> Backend health:  curl http://127.0.0.1:8000/health"
echo ">>> Frontend URL:    http://127.0.0.1:5173/"
echo ">>> To open in browser on Android:"
echo "termux-open-url http://127.0.0.1:5173/"
echo ">>> Logs:"
echo "tail -f $ROOT/backend.log"
echo "tail -f $ROOT/frontend.log"

