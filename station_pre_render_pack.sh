#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
FRONT="$ROOT/frontend"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT="$ROOT/station_logs/pre_render_check_$TS.log"

mkdir -p "$ROOT/station_logs"

log(){ echo "$@" | tee -a "$REPORT"; }

log "=== STATION PRE-RENDER PACK ==="
log "Time: $TS"
log "Root: $ROOT"
log

# ---------------------------
# 1) Backend hardening + endpoints + CORS
# ---------------------------
log "== [1/6] Backend: venv + deps + patch =="
cd "$BACK"

if [ ! -d ".venv" ]; then
  log "Creating backend venv..."
  python -m venv .venv
fi

# shellcheck disable=SC1091
source .venv/bin/activate

python -m pip install -U pip wheel setuptools | tee -a "$REPORT"

if [ -f "requirements.txt" ] && [ -s "requirements.txt" ]; then
  log "Installing backend requirements.txt..."
  pip install -r requirements.txt | tee -a "$REPORT"
else
  log "requirements.txt missing/empty; installing minimal runtime deps..."
  pip install "uvicorn[standard]" starlette | tee -a "$REPORT"
fi

log "Freezing requirements.txt (synchronized)..."
pip freeze > requirements.txt

# Create VERSION file if missing
cd "$ROOT"
if [ ! -f "VERSION" ]; then
  echo "station-1.0.0" > VERSION
fi

# Patch backend/main.py safely (append-only patch, avoids breaking existing structure)
cd "$BACK"
if [ -f "main.py" ]; then
  log "Patching backend/main.py (append Station ops block)..."
  python - <<'PY'
from pathlib import Path
p = Path("main.py")
txt = p.read_text(encoding="utf-8", errors="ignore")

marker = "# === STATION_OPS_BLOCK_V1 ==="
if marker in txt:
    print("Station ops block already present. Skipping.")
else:
    add = r'''
# === STATION_OPS_BLOCK_V1 ===
# Safe append: adds /info and /version and optional CORS without changing existing app wiring.
import os
import time

try:
    from starlette.responses import JSONResponse
    from starlette.routing import Route
    from starlette.middleware.cors import CORSMiddleware
except Exception:
    JSONResponse = None
    Route = None
    CORSMiddleware = None

def _station_now_iso():
    try:
        import datetime
        return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    except Exception:
        return None

def _station_version():
    # Try read VERSION from repo root
    try:
        here = os.path.dirname(__file__)
        root = os.path.abspath(os.path.join(here, ".."))
        vp = os.path.join(root, "VERSION")
        if os.path.exists(vp):
            return open(vp, "r", encoding="utf-8").read().strip()
    except Exception:
        pass
    return "station-unknown"

async def _station_info(request):
    return JSONResponse({
        "name": "station",
        "engine": "starlette-core",
        "env": os.getenv("ENV", "local"),
        "runtime": os.getenv("RUNTIME", "termux"),
        "version": _station_version(),
        "time": _station_now_iso(),
    })

async def _station_version_handler(request):
    return JSONResponse({
        "version": _station_version(),
        "time": _station_now_iso(),
    })

def _station_apply_cors(app_obj):
    if CORSMiddleware is None:
        return
    allowed = os.getenv("ALLOWED_ORIGINS", "")
    origins = [o.strip() for o in allowed.split(",") if o.strip()]
    # If not set, keep local dev friendly defaults (tight enough; no wildcard).
    if not origins:
        origins = ["http://localhost:5173", "http://127.0.0.1:5173"]
    try:
        # Avoid duplicating middleware if already present
        mids = getattr(app_obj, "user_middleware", []) or []
        for m in mids:
            if getattr(m, "cls", None) is CORSMiddleware:
                return
        app_obj.add_middleware(
            CORSMiddleware,
            allow_origins=origins,
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )
    except Exception:
        return

def _station_register_routes(app_obj):
    if JSONResponse is None or Route is None:
        return
    try:
        routes = getattr(app_obj.router, "routes", None)
        if routes is None:
            return
        paths = set(getattr(r, "path", None) for r in routes)
        if "/info" not in paths:
            routes.append(Route("/info", _station_info, methods=["GET"]))
        if "/version" not in paths:
            routes.append(Route("/version", _station_version_handler, methods=["GET"]))
    except Exception:
        return

try:
    # Expect app to exist in this module
    if "app" in globals():
        _station_apply_cors(app)
        _station_register_routes(app)
except Exception:
    pass
'''
    p.write_text(txt.rstrip() + "\n" + add + "\n", encoding="utf-8")
    print("Patched main.py successfully.")
PY
else
  log "WARNING: backend/main.py not found; skipping patch."
fi

# Create official backend runner
log "Creating backend/run_backend_official.sh ..."
cat > "$BACK/run_backend_official.sh" <<'BASH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

if [ -f .venv/bin/activate ]; then
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8000}"
export TARGET="${TARGET:-main:app}"

echo ">>> [station] backend target=$TARGET host=$HOST port=$PORT"
python -m uvicorn "$TARGET" --host "$HOST" --port "$PORT"
BASH
chmod +x "$BACK/run_backend_official.sh"

log "Backend prep done."
log

# ---------------------------
# 2) Frontend: install + ensure build works + .env.example
# ---------------------------
log "== [2/6] Frontend: deps + build + env example =="
cd "$FRONT"

if [ -f package.json ]; then
  log "npm install..."
  npm install | tee -a "$REPORT"
  log "Creating frontend/.env.example ..."
  cat > .env.example <<'ENV'
# Copy to .env.local for local dev
VITE_BACKEND_URL=http://127.0.0.1:8000
ENV
  log "Building frontend (Vite)..."
  # Use dev default if not provided
  export VITE_BACKEND_URL="${VITE_BACKEND_URL:-http://127.0.0.1:8000}"
  npm run build | tee -a "$REPORT"
else
  log "ERROR: frontend/package.json not found. Frontend missing?"
fi
log "Frontend prep done."
log

# ---------------------------
# 3) Checklist probes (curl endpoints)
# ---------------------------
log "== [3/6] Runtime checklist probes (backend endpoints) =="
cd "$BACK"
# Try quick probe assuming backend already running
log "Probing http://127.0.0.1:8000/health ..."
curl -s --max-time 2 http://127.0.0.1:8000/health | tee -a "$REPORT" || log "NOTE: backend not running yet."

log "Probing http://127.0.0.1:8000/info ..."
curl -s --max-time 2 http://127.0.0.1:8000/info | tee -a "$REPORT" || log "NOTE: /info not reachable (backend not running or patch not loaded)."

log "Probing http://127.0.0.1:8000/version ..."
curl -s --max-time 2 http://127.0.0.1:8000/version | tee -a "$REPORT" || log "NOTE: /version not reachable (backend not running or patch not loaded)."

log

# ---------------------------
# 4) Git hygiene (optional)
# ---------------------------
log "== [4/6] Git status (informational) =="
cd "$ROOT"
if [ -d .git ]; then
  git status | tee -a "$REPORT" || true
else
  log "No .git directory found at station_root (ok if not initialized yet)."
fi
log

# ---------------------------
# 5) Render readiness hints (written to file)
# ---------------------------
log "== [5/6] Writing Render commands hint file =="
cat > "$ROOT/RENDER_DEPLOY_HINTS.txt" <<'TXT'
Render Deploy Hints (Station)

Backend (Web Service):
- Root Directory: backend
- Build Command: pip install -r requirements.txt
- Start Command: uvicorn main:app --host 0.0.0.0 --port $PORT
- Env Vars:
  ENV=render
  RUNTIME=render
  ALLOWED_ORIGINS=https://<your-frontend>.onrender.com

Frontend (Static Site):
- Root Directory: frontend
- Build Command: npm ci && npm run build
- Publish Dir: dist
- Env Vars (build-time):
  VITE_BACKEND_URL=http://<backend-internal-host>:<port>
TXT
log "Render hints written: RENDER_DEPLOY_HINTS.txt"
log

# ---------------------------
# 6) Summary
# ---------------------------
log "== [6/6] Summary =="
log "Report: $REPORT"
log "Backend runner: backend/run_backend_official.sh"
log "Frontend env example: frontend/.env.example"
log "Render hints: RENDER_DEPLOY_HINTS.txt"
log "Done."
