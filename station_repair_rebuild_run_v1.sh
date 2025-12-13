#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
BE="$ROOT/backend"
FE="$ROOT/frontend"
LOG="$ROOT/station_logs"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT="$LOG/repair_rebuild_run_$TS.log"

mkdir -p "$LOG"

log(){ echo "$@" | tee -a "$REPORT"; }

log "================================================="
log " STATION REPAIR + REBUILD + RUN  (v1)"
log " Time: $TS"
log " Root: $ROOT"
log " Report: $REPORT"
log "================================================="
log

# -------------------------------------------------
# [0] Sanity + folders
# -------------------------------------------------
log "== [0] Sanity check folders =="
test -d "$ROOT" || { log "ERROR: Missing $ROOT"; exit 1; }
test -d "$BE"   || { log "ERROR: Missing $BE"; exit 1; }
test -d "$FE"   || { log "ERROR: Missing $FE"; exit 1; }
test -f "$BE/main.py" || { log "ERROR: Missing $BE/main.py"; exit 1; }
test -f "$FE/package.json" || { log "ERROR: Missing $FE/package.json"; exit 1; }
log "OK."
log

# -------------------------------------------------
# [1] Termux base packages (safe set)
# -------------------------------------------------
log "== [1] Termux base packages (safe) =="
if command -v pkg >/dev/null 2>&1; then
  pkg update -y | tee -a "$REPORT" || true
  pkg upgrade -y | tee -a "$REPORT" || true
  pkg install -y python git curl nodejs-lts | tee -a "$REPORT" || true
else
  log "NOTE: pkg not found (non-Termux?). Skipping base pkg install."
fi
log

# -------------------------------------------------
# [2] Kill old servers / ports
# -------------------------------------------------
log "== [2] Kill old servers (uvicorn/node/vite) =="
pkill -f "uvicorn" 2>/dev/null || true
pkill -f "vite" 2>/dev/null || true
pkill -f "npm run dev" 2>/dev/null || true
pkill -f "npm run preview" 2>/dev/null || true
command -v fuser >/dev/null 2>&1 && (fuser -k 8000/tcp 2>/dev/null || true) || true
command -v fuser >/dev/null 2>&1 && (fuser -k 5173/tcp 2>/dev/null || true) || true
sleep 0.6
log "OK."
log

# -------------------------------------------------
# [3] Ensure VERSION + env defaults
# -------------------------------------------------
log "== [3] Ensure VERSION + env defaults =="
cd "$ROOT"
if [ ! -f VERSION ]; then echo "r9600" > VERSION; fi
if [ ! -f station_env.example.sh ]; then
  cat > station_env.example.sh <<'ENV'
#!/data/data/com.termux/files/usr/bin/bash
set -e
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"

# Backend keys (edit later from UI)
export STATION_EDIT_KEY="1234"
export STATION_RUNNER_KEY="runner-1234"

# Optional (UI can pass api_key in body)
export OPENAI_API_KEY=""
export STATION_OPENAI_API_KEY="$OPENAI_API_KEY"
ENV
  chmod +x station_env.example.sh
fi
log "OK."
log

# -------------------------------------------------
# [4] Backend: venv rebuild + Termux-safe deps
#     IMPORTANT: avoid pydantic-core/rust extras
# -------------------------------------------------
log "== [4] Backend venv rebuild + deps (Termux-safe) =="
cd "$BE"
rm -rf .venv || true
python -m venv .venv
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install -U pip wheel setuptools | tee -a "$REPORT"

# Minimal deps (NO fastapi / NO uvicorn[standard])
pip install \
  "uvicorn==0.23.2" \
  "starlette==0.36.3" \
  "anyio==3.7.1" \
  "requests==2.31.0" \
  "python-multipart==0.0.9" \
  "click==8.3.1" \
  "h11==0.16.0" | tee -a "$REPORT"

cat > requirements.txt <<'REQ'
uvicorn==0.23.2
starlette==0.36.3
anyio==3.7.1
requests==2.31.0
python-multipart==0.0.9
click==8.3.1
h11==0.16.0
REQ
log "OK backend deps."
log

# -------------------------------------------------
# [5] Backend patch: enforce required routes (health/info/version/chat/ops + agent queue)
# -------------------------------------------------
log "== [5] Backend patch: force routes + agent bridge =="
cd "$BE"

# agent_queue.py (SQLite queue)
cat > agent_queue.py <<'PY'
import os, time, json, sqlite3
from typing import Optional, Dict, Any, List, Tuple

DB_PATH = os.getenv("STATION_AGENT_DB", os.path.join(os.path.dirname(__file__), "agent_queue.sqlite3"))

def _db():
    conn = sqlite3.connect(DB_PATH)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("""
    CREATE TABLE IF NOT EXISTS tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        runner_id TEXT,
        task_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        result_json TEXT,
        error_text TEXT
    )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_tasks_status ON tasks(status, created_at)")
    conn.commit()
    return conn

def _now() -> int:
    return int(time.time())

def submit_task(task_type: str, payload: Dict[str, Any]) -> int:
    conn = _db()
    cur = conn.cursor()
    cur.execute(
        "INSERT INTO tasks(created_at, status, runner_id, task_type, payload_json) VALUES(?, 'queued', NULL, ?, ?)",
        (_now(), task_type, json.dumps(payload, ensure_ascii=True)),
    )
    conn.commit()
    tid = int(cur.lastrowid)
    conn.close()
    return tid

def claim_next(runner_id: str) -> Optional[Tuple[int, Dict[str, Any], str]]:
    conn = _db()
    cur = conn.cursor()
    cur.execute("SELECT id, payload_json, task_type FROM tasks WHERE status='queued' ORDER BY created_at ASC LIMIT 1")
    row = cur.fetchone()
    if not row:
        conn.close()
        return None
    tid, payload_json, task_type = row
    cur.execute("UPDATE tasks SET status='running', runner_id=? WHERE id=? AND status='queued'", (runner_id, tid))
    conn.commit()
    cur.execute("SELECT status FROM tasks WHERE id=?", (tid,))
    st = cur.fetchone()
    if not st or st[0] != "running":
        conn.close()
        return None
    conn.close()
    return int(tid), json.loads(payload_json), str(task_type)

def set_result(tid: int, ok: bool, result: Dict[str, Any], error_text: str = "") -> None:
    conn = _db()
    cur = conn.cursor()
    cur.execute(
        "UPDATE tasks SET status=?, result_json=?, error_text=? WHERE id=?",
        ("done" if ok else "failed", json.dumps(result, ensure_ascii=True), error_text, tid),
    )
    conn.commit()
    conn.close()

def get_task(tid: int) -> Optional[Dict[str, Any]]:
    conn = _db()
    cur = conn.cursor()
    cur.execute("SELECT id, created_at, status, runner_id, task_type, payload_json, result_json, error_text FROM tasks WHERE id=?", (tid,))
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return {
        "id": row[0],
        "created_at": row[1],
        "status": row[2],
        "runner_id": row[3],
        "task_type": row[4],
        "payload": json.loads(row[5]) if row[5] else None,
        "result": json.loads(row[6]) if row[6] else None,
        "error": row[7],
    }

def list_recent(limit: int = 25) -> List[Dict[str, Any]]:
    conn = _db()
    cur = conn.cursor()
    cur.execute("SELECT id FROM tasks ORDER BY id DESC LIMIT ?", (int(limit),))
    ids = [r[0] for r in cur.fetchall()]
    conn.close()
    out = []
    for tid in ids:
        t = get_task(int(tid))
        if t:
            out.append(t)
    return out
PY

python - <<'PY'
from pathlib import Path

p = Path("main.py")
txt = p.read_text(encoding="utf-8", errors="ignore")

marker = "# === STATION_FORCE_CORE_V1 ==="
if marker not in txt:
    block = r'''
# === STATION_FORCE_CORE_V1 ===
import os, time, subprocess
from typing import Dict, Any

try:
    from starlette.responses import JSONResponse
    from starlette.routing import Route
except Exception:
    JSONResponse = None
    Route = None

def _now_iso():
    try:
        import datetime
        return datetime.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    except Exception:
        return None

def _read_version():
    try:
        root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
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

def _runner_key_ok(request) -> bool:
    want = os.getenv("STATION_RUNNER_KEY", "runner-1234")
    got = request.headers.get("x-runner-key", "")
    return bool(got) and got == want

_OPS_BUCKET: Dict[str, Dict[str, Any]] = {}
def _ops_allow(ip: str, limit: int = 40):
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

def _run(cmd, cwd=None, timeout=120):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

async def station_health(request):
    return JSONResponse({"status":"ok","runtime":"station","env":os.getenv("ENV","termux"),"engine":os.getenv("ENGINE","starlette-core")})

async def station_info(request):
    return JSONResponse({"name":"station","engine":os.getenv("ENGINE","starlette-core"),"env":os.getenv("ENV","local"),"runtime":os.getenv("RUNTIME","termux"),"version":_read_version(),"time":_now_iso()})

async def station_version(request):
    return JSONResponse({"version":_read_version(),"time":_now_iso()})

async def ops_git_status(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok":False,"error":"unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok":False,"error":"rate_limited"}, status_code=429)
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    rc, out, err = _run(["git","status","--porcelain=v1","-b"], cwd=root)
    return JSONResponse({"ok":rc==0,"rc":rc,"out":out,"err":err})

async def ops_git_push(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok":False,"error":"unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok":False,"error":"rate_limited"}, status_code=429)
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    _run(["git","add","-A"], cwd=root, timeout=180)
    rc1, out1, err1 = _run(["git","commit","-m","station: ops commit"], cwd=root, timeout=180)
    rc2, out2, err2 = _run(["git","push"], cwd=root, timeout=240)
    return JSONResponse({"ok":rc2==0,"commit":{"rc":rc1,"out":out1,"err":err1},"push":{"rc":rc2,"out":out2,"err":err2}})

# /chat: raw proxy to OpenAI Responses API (frontend may pass api_key)
async def station_chat(request):
    try:
        body = await request.json()
    except Exception:
        body = {}
    user_input = (body.get("input") or "").strip()
    api_key = (body.get("api_key") or os.getenv("OPENAI_API_KEY") or os.getenv("STATION_OPENAI_API_KEY") or "").strip()
    model = (body.get("model") or "gpt-5").strip()
    if not user_input:
        return JSONResponse({"ok":False,"error":"missing_input"}, status_code=400)
    if not api_key:
        return JSONResponse({"ok":False,"error":"missing_api_key"}, status_code=400)

    import requests
    r = requests.post(
        "https://api.openai.com/v1/responses",
        headers={"Authorization": f"Bearer {api_key}", "Content-Type":"application/json"},
        json={"model": model, "input": user_input},
        timeout=60,
    )
    try:
        data = r.json()
    except Exception:
        return JSONResponse({"ok":False,"status":r.status_code,"text":r.text}, status_code=502)
    return JSONResponse({"ok": r.ok, "status": r.status_code, "data": data})
'''
    txt = txt.rstrip() + "\n\n" + marker + "\n" + block + "\n"

marker2 = "# === STATION_AGENT_BRIDGE_V1 ==="
if marker2 not in txt:
    block2 = r'''
# === STATION_AGENT_BRIDGE_V1 ===
import os
try:
    from starlette.responses import JSONResponse
    from starlette.routing import Route
except Exception:
    JSONResponse = None
    Route = None

from agent_queue import submit_task, claim_next, set_result, get_task, list_recent

async def agent_submit(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    try:
        body = await request.json()
    except Exception:
        body = {}
    task_type = (body.get("task_type") or "shell").strip()
    payload = body.get("payload") or {}
    tid = submit_task(task_type, payload)
    return JSONResponse({"ok": True, "task_id": tid})

async def agent_next(request):
    if not _runner_key_ok(request):
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    runner_id = request.query_params.get("runner_id") or "termux"
    got = claim_next(runner_id)
    if not got:
        return JSONResponse({"ok": True, "task": None})
    tid, payload, task_type = got
    return JSONResponse({"ok": True, "task": {"id": tid, "task_type": task_type, "payload": payload}})

async def agent_result(request):
    if not _runner_key_ok(request):
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    try:
        body = await request.json()
    except Exception:
        body = {}
    tid = int(body.get("task_id") or 0)
    ok = bool(body.get("ok"))
    result = body.get("result") or {}
    err = body.get("error") or ""
    if tid <= 0:
        return JSONResponse({"ok": False, "error": "missing_task_id"}, status_code=400)
    set_result(tid, ok, result, err)
    return JSONResponse({"ok": True})

async def agent_task_get(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    tid = int(request.path_params.get("tid") or 0)
    t = get_task(tid)
    return JSONResponse({"ok": True, "task": t})

async def agent_recent(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    lim = int(request.query_params.get("limit") or 25)
    return JSONResponse({"ok": True, "items": list_recent(lim)})
'''
    txt = txt.rstrip() + "\n\n" + marker2 + "\n" + block2 + "\n"

marker3 = "# === STATION_ROUTE_REG_V1 ==="
if marker3 not in txt:
    reg = r'''
# === STATION_ROUTE_REG_V1 ===
def _station_register_all_routes(app_obj):
    if Route is None:
        return
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

    add("/agent/tasks/submit", agent_submit, ["POST"])
    add("/agent/tasks/next", agent_next, ["GET"])
    add("/agent/tasks/result", agent_result, ["POST"])
    add("/agent/tasks/recent", agent_recent, ["GET"])
    add("/agent/tasks/{tid:int}", agent_task_get, ["GET"])

try:
    if "app" in globals():
        _station_register_all_routes(app)
except Exception:
    pass
'''
    txt = txt.rstrip() + "\n\n" + marker3 + "\n" + reg + "\n"

p.write_text(txt, encoding="utf-8")
print("OK: backend routes enforced (core + agent).")
PY

log "OK backend patched."
log

# -------------------------------------------------
# [6] Backend runner (official)
# -------------------------------------------------
log "== [6] Backend runner script =="
cat > "$BE/run_backend_official.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
# shellcheck disable=SC1091
[ -f .venv/bin/activate ] && source .venv/bin/activate
export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8000}"
export ENV="${ENV:-local}"
export RUNTIME="${RUNTIME:-termux}"
export ENGINE="${ENGINE:-starlette-core}"
export STATION_EDIT_KEY="${STATION_EDIT_KEY:-1234}"
export STATION_RUNNER_KEY="${STATION_RUNNER_KEY:-runner-1234}"
echo ">>> [station] backend main:app @ $HOST:$PORT"
python -m uvicorn main:app --host "$HOST" --port "$PORT"
SH
chmod +x "$BE/run_backend_official.sh"
log "OK."
log

# -------------------------------------------------
# [7] Frontend: clean install + build + dev
# -------------------------------------------------
log "== [7] Frontend install/build (Vite) =="
cd "$FE"
rm -rf node_modules package-lock.json dist 2>/dev/null || true
npm install | tee -a "$REPORT"
# build optional (dev will run anyway)
npm run build | tee -a "$REPORT" || true
log "OK frontend."
log

# -------------------------------------------------
# [8] Start backend + frontend (background) + smoke
# -------------------------------------------------
log "== [8] Start services =="
mkdir -p "$LOG"

# backend
cd "$BE"
( nohup ./run_backend_official.sh > "$LOG/backend_run.log" 2>&1 & echo $! > "$LOG/backend.pid" ) || true
sleep 1.2

# frontend dev
cd "$FE"
( nohup npm run dev -- --host 0.0.0.0 --port 5173 > "$LOG/frontend_dev.log" 2>&1 & echo $! > "$LOG/frontend.pid" ) || true
sleep 1.2

log "== [9] Smoke tests (must be 200 + JSON) =="
curl -s "http://127.0.0.1:8000/health" | tee -a "$REPORT"; echo | tee -a "$REPORT"
curl -s "http://127.0.0.1:8000/info"   | tee -a "$REPORT"; echo | tee -a "$REPORT"
curl -s "http://127.0.0.1:8000/version"| tee -a "$REPORT"; echo | tee -a "$REPORT"

log
log "== [10] Open browser =="
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "http://127.0.0.1:5173"
else
  log "Open manually: http://127.0.0.1:5173"
fi

log
log "================================================="
log "DONE. Station should be UP."
log "Backend : http://127.0.0.1:8000"
log "Frontend: http://127.0.0.1:5173"
log "Logs:"
log "  tail -n 200 $LOG/backend_run.log"
log "  tail -n 200 $LOG/frontend_dev.log"
log "Report:"
log "  $REPORT"
log "================================================="
