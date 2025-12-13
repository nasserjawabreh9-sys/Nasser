#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
BE="$ROOT/backend"
FE="$ROOT/frontend"
LOG="$ROOT/station_logs"
OPS="$ROOT/scripts/ops"

mkdir -p "$LOG" "$OPS"

echo "=== [0] Sanity ==="
test -d "$BE" || { echo "Missing backend dir: $BE"; exit 1; }
test -d "$FE" || { echo "Missing frontend dir: $FE"; exit 1; }

echo "=== [1] Kill ports 8000/5173 (fix errno 98) ==="
# best-effort kill (Termux varies)
pkill -f "uvicorn.*:8000" 2>/dev/null || true
pkill -f "uvicorn.*8000" 2>/dev/null || true
pkill -f "vite.*5173" 2>/dev/null || true
pkill -f "node.*5173" 2>/dev/null || true
command -v fuser >/dev/null 2>&1 && (fuser -k 8000/tcp 2>/dev/null || true) || true
command -v fuser >/dev/null 2>&1 && (fuser -k 5173/tcp 2>/dev/null || true) || true
sleep 0.5

echo "=== [2] Backend venv + Termux-safe deps (NO rust) ==="
cd "$BE"
if [ ! -d ".venv" ]; then
  python -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install -U pip wheel setuptools >/dev/null
# IMPORTANT: do NOT use uvicorn[standard] on Termux/Py312 (watchfiles/uvloop/rust)
pip install \
  "uvicorn==0.23.2" \
  "starlette==0.36.3" \
  "anyio==3.7.1" \
  "requests==2.31.0" \
  "python-multipart==0.0.9" \
  "click==8.3.1" \
  "h11==0.16.0" >/dev/null

echo "=== [3] Ensure VERSION ==="
cd "$ROOT"
if [ ! -f VERSION ]; then echo "r9600" > VERSION; fi

echo "=== [4] Patch backend main.py: force Station routes (health/info/version/chat/ops) ==="
cd "$BE"
test -f main.py || { echo "Missing: $BE/main.py"; exit 1; }

python - <<'PY'
from pathlib import Path

p = Path("main.py")
txt = p.read_text(encoding="utf-8", errors="ignore")

marker = "# === STATION_FORCE_ROUTES_V1 ==="
if marker in txt:
    print("Backend force-routes block already present.")
    raise SystemExit(0)

block = r'''
# === STATION_FORCE_ROUTES_V1 ===
import os, json, time, subprocess
from typing import Dict, Any

try:
    from starlette.responses import JSONResponse, PlainTextResponse
    from starlette.routing import Route
except Exception:
    JSONResponse = None
    PlainTextResponse = None
    Route = None

def _now_iso():
    try:
        import datetime
        return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    except Exception:
        return None

def _read_version():
    try:
        here = os.path.dirname(__file__)
        root = os.path.abspath(os.path.join(here, ".."))
        vp = os.path.join(root, "VERSION")
        if os.path.exists(vp):
            return open(vp, "r", encoding="utf-8").read().strip()
    except Exception:
        pass
    return "station-unknown"

def _edit_key_ok(request) -> bool:
    want = os.getenv("STATION_EDIT_KEY", "1234")
    got = request.headers.get("x-edit-key", "")
    return bool(got) and got == want

_OPS_BUCKET: Dict[str, Dict[str, Any]] = {}
def _ops_allow(ip: str, limit: int = 30):
    now = int(time.time())
    w = now // 60
    b = _OPS_BUCKET.get(ip)
    if not b or b.get("w") != w:
        _OPS_BUCKET[ip] = {"w": w, "c": 1}
        return True
    if b["c"] >= limit:
        return False
    b["c"] += 1
    return True

async def station_health(request):
    return JSONResponse({"status":"ok","runtime":"station","env":os.getenv("ENV","termux"),"engine":os.getenv("ENGINE","starlette-core")})

async def station_info(request):
    return JSONResponse({
        "name":"station",
        "engine": os.getenv("ENGINE","starlette-core"),
        "env": os.getenv("ENV","local"),
        "runtime": os.getenv("RUNTIME","termux"),
        "version": _read_version(),
        "time": _now_iso(),
    })

async def station_version(request):
    return JSONResponse({"version": _read_version(), "time": _now_iso()})

def _run(cmd, cwd=None, timeout=60):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

async def ops_git_status(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok":False,"error":"unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok":False,"error":"rate_limited"}, status_code=429)
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    rc, out, err = _run(["git","status","--porcelain=v1","-b"], cwd=root)
    return JSONResponse({"ok": rc==0, "rc": rc, "out": out, "err": err})

async def ops_git_push(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok":False,"error":"unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok":False,"error":"rate_limited"}, status_code=429)
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    _run(["git","add","-A"], cwd=root, timeout=120)
    rc1, out1, err1 = _run(["git","commit","-m","station: ops commit"], cwd=root, timeout=120)
    rc2, out2, err2 = _run(["git","push"], cwd=root, timeout=180)
    return JSONResponse({"ok": rc2==0, "commit":{"rc":rc1,"out":out1,"err":err1}, "push":{"rc":rc2,"out":out2,"err":err2}})

async def ops_render_deploy(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok":False,"error":"unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok":False,"error":"rate_limited"}, status_code=429)

    try:
        body = await request.json()
    except Exception:
        body = {}

    api_key = (body.get("render_api_key") or os.getenv("RENDER_API_KEY") or "").strip()
    service_id = (body.get("render_service_id") or os.getenv("RENDER_SERVICE_ID") or "").strip()
    if not api_key or not service_id:
        return JSONResponse({"ok":False,"error":"missing_render_api_key_or_service_id"}, status_code=400)

    import requests
    url = f"https://api.render.com/v1/services/{service_id}/deploys"
    r = requests.post(url, headers={"Authorization": f"Bearer {api_key}"}, timeout=30)
    try:
        jj = r.json() if r.content else None
    except Exception:
        jj = r.text
    return JSONResponse({"ok": r.ok, "status": r.status_code, "json": jj})

# ---- CHAT endpoint (uses OpenAI Responses API) ----
# Frontend can send api_key in body; backend will fallback to env OPENAI_API_KEY.
# Endpoint: POST /chat { "input": "...", "api_key": "...", "model": "gpt-5" }
async def station_chat(request):
    try:
        body = await request.json()
    except Exception:
        body = {}

    user_input = (body.get("input") or "").strip()
    api_key = (body.get("api_key") or os.getenv("OPENAI_API_KEY") or os.getenv("STATION_OPENAI_API_KEY") or "").strip()
    model = (body.get("model") or "gpt-5").strip()

    if not user_input:
        return JSONResponse({"ok": False, "error": "missing_input"}, status_code=400)
    if not api_key:
        return JSONResponse({"ok": False, "error": "missing_api_key"}, status_code=400)

    import requests
    url = "https://api.openai.com/v1/responses"
    payload = {
        "model": model,
        "input": user_input
    }
    r = requests.post(url, headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }, json=payload, timeout=60)

    # Return raw JSON (frontend can render output_text or parse output)
    try:
        data = r.json()
    except Exception:
        return JSONResponse({"ok": False, "status": r.status_code, "text": r.text}, status_code=502)

    return JSONResponse({"ok": r.ok, "status": r.status_code, "data": data})

def _force_add_routes(app_obj):
    if Route is None:
        return
    try:
        routes = getattr(app_obj.router, "routes", None)
        if routes is None:
            return
        existing = set(getattr(r, "path", None) for r in routes)

        def add(path, fn, methods):
            if path not in existing:
                routes.append(Route(path, fn, methods=methods))
                existing.add(path)

        add("/health", station_health, ["GET"])
        add("/info", station_info, ["GET"])
        add("/version", station_version, ["GET"])
        add("/chat", station_chat, ["POST"])
        add("/ops/git/status", ops_git_status, ["POST"])
        add("/ops/git/push", ops_git_push, ["POST"])
        add("/ops/render/deploy", ops_render_deploy, ["POST"])
    except Exception:
        pass

try:
    if "app" in globals():
        _force_add_routes(app)
except Exception:
    pass
'''

p.write_text(txt.rstrip() + "\n\n" + marker + "\n" + block + "\n", encoding="utf-8")
print("Patched main.py with STATION_FORCE_ROUTES_V1.")
PY

echo "=== [5] Backend runner ==="
cat > "$BE/run_backend_official.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
[ -f .venv/bin/activate ] && source .venv/bin/activate
export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8000}"
export TARGET="${TARGET:-main:app}"
echo ">>> [station] backend $TARGET @ $HOST:$PORT"
python -m uvicorn "$TARGET" --host "$HOST" --port "$PORT"
SH
chmod +x "$BE/run_backend_official.sh"

echo "=== [6] Frontend: install + dev server prepare ==="
cd "$FE"
npm install >/dev/null
npm install -D typescript >/dev/null

echo "=== [7] Smoke script v3 (backend) ==="
cat > "$OPS/station_runtime_smoke_v3.sh" <<'SMOKE'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
BASE="${1:-http://127.0.0.1:8000}"
EDIT="${2:-1234}"

echo "== health =="; curl -s "$BASE/health"; echo
echo "== info =="; curl -s "$BASE/info"; echo
echo "== version =="; curl -s "$BASE/version"; echo
echo "== ops git status =="; curl -s -X POST "$BASE/ops/git/status" -H "x-edit-key: $EDIT" -H "Content-Type: application/json" -d '{}'; echo
SMOKE
chmod +x "$OPS/station_runtime_smoke_v3.sh"

echo "=== [8] Start backend + frontend in background ==="
# start backend
cd "$BE"
( nohup ./run_backend_official.sh > "$LOG/backend_run.log" 2>&1 & echo $! > "$LOG/backend.pid" ) || true
sleep 0.8

# start frontend dev
cd "$FE"
( nohup npm run dev -- --host 0.0.0.0 --port 5173 > "$LOG/frontend_dev.log" 2>&1 & echo $! > "$LOG/frontend.pid" ) || true
sleep 1.0

echo "=== [9] Smoke backend now ==="
"$OPS/station_runtime_smoke_v3.sh" "http://127.0.0.1:8000" "1234" || true

echo "=== [10] Open browser ==="
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "http://127.0.0.1:5173"
else
  echo "Open manually: http://127.0.0.1:5173"
fi

echo
echo "DONE."
echo "Logs:"
echo "  tail -n 200 $LOG/backend_run.log"
echo "  tail -n 200 $LOG/frontend_dev.log"
