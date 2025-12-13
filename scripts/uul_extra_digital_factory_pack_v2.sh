#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
FRONT="$ROOT/frontend"
LOGS="$ROOT/station_logs"
DIG="$ROOT/digital"
SCRIPTS="$ROOT/scripts"
ENVF="$ROOT/station_env.sh"

mkdir -p "$SCRIPTS" "$LOGS" "$DIG/spec" "$DIG/run" "$DIG/out"

stamp(){ date -Iseconds; }
say(){ echo "==[UUL-EXTRA v2]== $*"; }

say "START $(stamp)"

# =========================================================
# 1) IDENTITY (DIGITAL) + HEADLINES (DIGITAL)
# =========================================================
cat > "$DIG/IDENTITY.json" <<'JSON'
{
  "system":"station",
  "layer":"UUL-EXTRA",
  "pack":"digital_factory_v2",
  "identity":{
    "owner":"Nasser Jawabreh",
    "signature":"operational_signature_v1",
    "policy":"digital-first / no-drift / rooms+dynamo+loop"
  },
  "edit_mode":{
    "header":"x-edit-key",
    "default_hint":"1234"
  },
  "keys_policy":{
    "never_embed_real_keys_in_code":true,
    "allowed_storage":["browser_localStorage","station_env.sh (quoted exports)"],
    "preferred":"UI -> Save Keys -> backend"
  }
}
JSON

cat > "$DIG/HEADLINES.md" <<'MD'
# DIGITAL HEADLINES (Station Factory)
- Identity is file-based (IDENTITY.json)
- Chat Tree is file-based (spec/chat_tree.json)
- Environment Matrix is file-based (spec/env_matrix.json)
- Execution is file-based (run/*.sh)
- Backend wiring is file-based (patch markers in backend/main.py)
- Factory is real endpoints: /uul/factory/* + /uul/loop/*
- Loop 4 is a real runner: polls tasks -> executes -> reports results
MD

# =========================================================
# 2) CHAT TREE (DIGITAL)
# =========================================================
cat > "$DIG/spec/chat_tree.json" <<'JSON'
{
  "tree":"station_chat_tree_v2",
  "root":"menu",
  "menus":{
    "menu":["factory","loop","rooms","keys","ops","status"],
    "factory":["run","status","logs"],
    "loop":["loop4_runner","loop5_github","loop6_render"],
    "rooms":["core","backend","frontend","tests","git_pipeline","render_deploy"],
    "keys":["openai","github","render","tts","hooks","ocr","whatsapp","email"],
    "ops":["git_status","git_push","render_deploy_hint"],
    "status":["health","info","version","logs"]
  }
}
JSON

# =========================================================
# 3) ENV MATRIX (DIGITAL) – Termux/GitHub/Render/Android
# =========================================================
cat > "$DIG/spec/env_matrix.json" <<'JSON'
{
  "env_matrix":"station_env_matrix_v2",
  "termux":{
    "python":">=3.11",
    "node":">=18",
    "notes":[
      "UTF-8 enforced",
      "avoid heavy native builds when possible",
      "ports: backend 8000, frontend 5173"
    ],
    "required_commands":["bash","python","pip","node","npm","git","curl"]
  },
  "github":{
    "branch":"main",
    "flow":"termux -> git push -> render auto deploy",
    "notes":["origin must be set once","token stored in UI/ENV only"]
  },
  "render":{
    "mode":"auto-deploy-from-github",
    "notes":["render dashboard controls build/start","no hardcoded render token in code"]
  },
  "android":{
    "device":"mobile",
    "channels":["text","mic","camera","video"],
    "notes":["UI is command center; heavy work happens in Termux workers"]
  }
}
JSON

# =========================================================
# 4) FIX station_env.sh (DIGITAL SAFE EXPORTS)
#    - solves your exact error: export OPENAI_API_KEYsk-... invalid identifier
# =========================================================
if [ ! -f "$ENVF" ]; then
  cat > "$ENVF" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -e
# IMPORTANT: keep quotes. Put ONLY the key value between quotes.
export STATION_OPENAI_API_KEY=""
export OPENAI_API_KEY="$STATION_OPENAI_API_KEY"
export GITHUB_TOKEN=""
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"
echo ">>> [STATION] Environment loaded:"
echo "    OPENAI_API_KEY          = set? $( [ -n "$OPENAI_API_KEY" ] && echo yes || echo no )"
echo "    STATION_OPENAI_API_KEY  = set? $( [ -n "$STATION_OPENAI_API_KEY" ] && echo yes || echo no )"
echo "    GITHUB_TOKEN            = set? $( [ -n "$GITHUB_TOKEN" ] && echo yes || echo no )"
SH
  chmod +x "$ENVF"
fi

# =========================================================
# 5) BACKEND: UUL CORE (Factory + Loop + Task Bus) – DIGITAL MODULES
#    - we namespace under /uul/* to avoid collisions with your existing endpoints
# =========================================================
mkdir -p "$BACK/uul_core"

cat > "$BACK/uul_core/__init__.py" <<'PY'
PY

cat > "$BACK/uul_core/state.py" <<'PY'
from __future__ import annotations
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Any

def now_ts() -> int:
    return int(time.time())

@dataclass
class RoomState:
    name: str
    status: str = "idle"  # idle|running|done|error
    updated_at: int = field(default_factory=now_ts)
    last_error: str = ""

@dataclass
class Task:
    id: int
    created_at: int
    status: str          # queued|running|done|error
    task_type: str       # shell|python|noop
    payload: Dict[str, Any]
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    runner_id: Optional[str] = None

@dataclass
class UULState:
    running: bool = False
    started_at: Optional[int] = None
    rooms: Dict[str, RoomState] = field(default_factory=dict)
    logs: List[str] = field(default_factory=list)
    tasks: List[Task] = field(default_factory=list)
    next_task_id: int = 1

    def log(self, msg: str) -> None:
        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        line = f"{ts} {msg}"
        self.logs.append(line)
        if len(self.logs) > 4000:
            self.logs = self.logs[-2000:]

STATE = UULState()
PY

cat > "$BACK/uul_core/rooms.py" <<'PY'
from __future__ import annotations
import os, subprocess
from .state import STATE

ROOT = os.path.expanduser("~/station_root")

def _run(cmd: str, cwd: str | None = None) -> tuple[int, str]:
    p = subprocess.Popen(cmd, cwd=cwd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out, _ = p.communicate()
    return p.returncode, (out or "").strip()

def core():
    STATE.log("[room:core] start")
    rc, out = _run("ls -la | head", cwd=ROOT)
    STATE.log(f"[room:core] rc={rc}")
    if out: STATE.log(out)

def backend():
    STATE.log("[room:backend] start")
    rc, out = _run("cd backend && python -V && ls -la | head", cwd=ROOT)
    STATE.log(f"[room:backend] rc={rc}")
    if out: STATE.log(out)

def frontend():
    STATE.log("[room:frontend] start")
    rc, out = _run("cd frontend && node -v && npm -v && ls -la | head", cwd=ROOT)
    STATE.log(f"[room:frontend] rc={rc}")
    if out: STATE.log(out)

def tests():
    STATE.log("[room:tests] start")
    rc1, h = _run("curl -s http://127.0.0.1:8000/health || true", cwd=ROOT)
    STATE.log(f"[room:tests] health_rc={rc1} body={h[:160]}")
    rc2, i = _run("curl -s http://127.0.0.1:8000/info || true", cwd=ROOT)
    STATE.log(f"[room:tests] info_rc={rc2} body={i[:160]}")

def git_pipeline():
    STATE.log("[room:git_pipeline] start")
    rc, out = _run("git status -sb || true", cwd=ROOT)
    STATE.log(f"[room:git_pipeline] rc={rc}")
    if out: STATE.log(out)

def render_deploy():
    STATE.log("[room:render_deploy] start")
    STATE.log("[room:render_deploy] hint: Render auto-deploys after GitHub push if connected")
PY

cat > "$BACK/uul_core/dynamo.py" <<'PY'
from __future__ import annotations
import time
from .state import STATE, RoomState
from . import rooms

ROOMS = {
    "core": rooms.core,
    "backend": rooms.backend,
    "frontend": rooms.frontend,
    "tests": rooms.tests,
    "git_pipeline": rooms.git_pipeline,
    "render_deploy": rooms.render_deploy,
}

ORDER = ["core","backend","frontend","tests","git_pipeline","render_deploy"]

def ensure_rooms():
    for n in ORDER:
        if n not in STATE.rooms:
            STATE.rooms[n] = RoomState(name=n)

def run_factory():
    ensure_rooms()
    if STATE.running:
        STATE.log("[dynamo] already running")
        return
    STATE.running = True
    STATE.started_at = int(time.time())
    STATE.log("[dynamo] START")
    try:
        for n in ORDER:
            rs = STATE.rooms[n]
            rs.status = "running"
            rs.updated_at = int(time.time())
            rs.last_error = ""
            STATE.log(f"[dynamo] room={n} status=running")
            try:
                ROOMS[n]()
                rs.status = "done"
                rs.updated_at = int(time.time())
                STATE.log(f"[dynamo] room={n} status=done")
            except Exception as e:
                rs.status = "error"
                rs.updated_at = int(time.time())
                rs.last_error = str(e)
                STATE.log(f"[dynamo] room={n} status=error err={e}")
                break
    finally:
        STATE.running = False
        STATE.log("[dynamo] STOP")
PY

cat > "$BACK/uul_core/taskbus.py" <<'PY'
from __future__ import annotations
from typing import Any, Dict, Optional
from .state import STATE, Task, now_ts

def submit(task_type: str, payload: Dict[str, Any]) -> int:
    tid = STATE.next_task_id
    STATE.next_task_id += 1
    t = Task(
        id=tid,
        created_at=now_ts(),
        status="queued",
        task_type=task_type,
        payload=payload,
    )
    STATE.tasks.append(t)
    STATE.log(f"[taskbus] submitted id={tid} type={task_type}")
    return tid

def next_task(runner_id: str) -> Optional[Task]:
    # find first queued
    for t in STATE.tasks:
        if t.status == "queued":
            t.status = "running"
            t.runner_id = runner_id
            STATE.log(f"[taskbus] dispatch id={t.id} runner={runner_id}")
            return t
    return None

def report(task_id: int, ok: bool, result: Dict[str, Any] | None = None, error: str | None = None) -> bool:
    for t in STATE.tasks:
        if t.id == task_id:
            t.status = "done" if ok else "error"
            t.result = result
            t.error = error
            STATE.log(f"[taskbus] report id={task_id} status={t.status}")
            return True
    return False

def recent(limit: int = 20):
    return list(reversed(STATE.tasks))[:max(1, min(200, limit))]
PY

cat > "$BACK/uul_core/api.py" <<'PY'
from __future__ import annotations
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from .state import STATE
from .dynamo import run_factory
from .taskbus import submit, next_task, report, recent

def _edit_ok(req: Request) -> bool:
    # keep minimal: presence of header.
    # your existing system can harden it later.
    return bool(req.headers.get("x-edit-key",""))

async def uul_factory_run(req: Request):
    if not _edit_ok(req):
        return JSONResponse({"ok":False,"error":"missing x-edit-key"}, status_code=401)
    run_factory()
    return JSONResponse({"ok":True,"running":STATE.running})

async def uul_factory_status(req: Request):
    tail = int(req.query_params.get("tail","160"))
    rooms = {k: {"status":v.status,"updated_at":v.updated_at,"last_error":v.last_error} for k,v in STATE.rooms.items()}
    return JSONResponse({
        "ok":True,
        "running":STATE.running,
        "started_at":STATE.started_at,
        "rooms":rooms,
        "log_tail": STATE.logs[-max(10, min(4000, tail)):]
    })

async def uul_task_submit(req: Request):
    if not _edit_ok(req):
        return JSONResponse({"ok":False,"error":"missing x-edit-key"}, status_code=401)
    body = await req.json()
    task_type = body.get("task_type","shell")
    payload = body.get("payload",{})
    tid = submit(task_type, payload)
    return JSONResponse({"ok":True,"task_id":tid})

async def uul_task_next(req: Request):
    runner_id = req.query_params.get("runner_id","runner-local")
    t = next_task(runner_id)
    if not t:
        return JSONResponse({"ok":True,"task":None})
    return JSONResponse({"ok":True,"task":{
        "id":t.id,
        "task_type":t.task_type,
        "payload":t.payload
    }})

async def uul_task_report(req: Request):
    body = await req.json()
    task_id = int(body.get("task_id",0))
    ok = bool(body.get("ok",False))
    result = body.get("result")
    error = body.get("error")
    done = report(task_id, ok, result=result, error=error)
    return JSONResponse({"ok":done})

async def uul_task_recent(req: Request):
    limit = int(req.query_params.get("limit","10"))
    items = []
    for t in recent(limit):
        items.append({
            "id": t.id,
            "created_at": t.created_at,
            "status": t.status,
            "runner_id": t.runner_id,
            "task_type": t.task_type,
            "payload": t.payload,
            "result": t.result,
            "error": t.error
        })
    return JSONResponse({"ok":True,"items":items})

def routes():
    return [
        Route("/uul/factory/run", uul_factory_run, methods=["POST"]),
        Route("/uul/factory/status", uul_factory_status, methods=["GET"]),
        Route("/uul/tasks/submit", uul_task_submit, methods=["POST"]),
        Route("/uul/tasks/next", uul_task_next, methods=["GET"]),
        Route("/uul/tasks/report", uul_task_report, methods=["POST"]),
        Route("/uul/tasks/recent", uul_task_recent, methods=["GET"]),
    ]
PY

# =========================================================
# 6) BACKEND WIRING PATCH (ROOT/FUNCTIONS/HEADERS/ENDPOINTS)
# =========================================================
MAIN="$BACK/main.py"
if [ -f "$MAIN" ]; then
  python - <<'PY'
from pathlib import Path

p = Path.home() / "station_root" / "backend" / "main.py"
s = p.read_text(encoding="utf-8", errors="ignore")
marker = "# === UUL_EXTRA_DIGITAL_FACTORY_V2 ==="
if marker in s:
    print("OK: patch already present")
    raise SystemExit(0)

add = r'''
# === UUL_EXTRA_DIGITAL_FACTORY_V2 ===
# Registers /uul/* endpoints (factory + loop taskbus) without colliding with existing routes.
try:
    from uul_core.api import routes as _uul_routes
    if "app" in globals():
        try:
            for r in _uul_routes():
                app.router.routes.append(r)
        except Exception:
            pass
except Exception:
    pass
'''
p.write_text(s.rstrip() + "\n\n" + marker + "\n" + add + "\n", encoding="utf-8")
print("OK: appended UUL routes hook")
PY
else
  say "WARN backend/main.py not found – skipped wiring"
fi

# =========================================================
# 7) DIGITAL RUNNER LOOP 4 (REAL) – executes tasks locally
# =========================================================
cat > "$ROOT/station_runner_loop4_uul.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
ENVF="$ROOT/station_env.sh"
LOG="$ROOT/station_logs/loop4_runner.log"
RUNNER_ID="termux-loop4"

mkdir -p "$ROOT/station_logs"

echo "==============================" | tee -a "$LOG"
echo "[LOOP4] START $(date -Iseconds)" | tee -a "$LOG"
echo "runner_id=$RUNNER_ID" | tee -a "$LOG"
echo "==============================" | tee -a "$LOG"

# Load ENV (safe)
if [ -f "$ENVF" ]; then
  source "$ENVF" >> "$LOG" 2>&1 || true
else
  echo "[LOOP4] ERROR: station_env.sh missing" | tee -a "$LOG"
  exit 1
fi

# Backend must be running separately (your existing runner loop for uvicorn is fine)
while true; do
  # fetch next task
  RESP="$(curl -s "http://127.0.0.1:8000/uul/tasks/next?runner_id=$RUNNER_ID" || true)"
  echo "[LOOP4] next: $RESP" | tee -a "$LOG"

  HAS_TASK="$(echo "$RESP" | grep -q '"task":null' && echo no || echo yes)"
  if [ "$HAS_TASK" = "no" ]; then
    sleep 2
    continue
  fi

  TASK_ID="$(echo "$RESP" | python -c 'import sys,json; d=json.load(sys.stdin); print(d["task"]["id"])' 2>/dev/null || echo 0)"
  TASK_TYPE="$(echo "$RESP" | python -c 'import sys,json; d=json.load(sys.stdin); print(d["task"]["task_type"])' 2>/dev/null || echo shell)"

  if [ "$TASK_ID" = "0" ]; then
    sleep 2
    continue
  fi

  echo "[LOOP4] executing task_id=$TASK_ID type=$TASK_TYPE" | tee -a "$LOG"

  OK=true
  OUT=""
  ERR=""

  if [ "$TASK_TYPE" = "shell" ]; then
    # payload: {"cwd":"...","script_b64":"..."}
    CWD="$(echo "$RESP" | python -c 'import sys,json; d=json.load(sys.stdin); print(d["task"]["payload"].get("cwd",""))' 2>/dev/null || echo "")"
    B64="$(echo "$RESP" | python -c 'import sys,json; d=json.load(sys.stdin); print(d["task"]["payload"].get("script_b64",""))' 2>/dev/null || echo "")"

    if [ -z "$B64" ]; then
      OK=false
      ERR="missing script_b64"
    else
      TMP="$ROOT/station_logs/_loop4_task_${TASK_ID}.sh"
      echo "$B64" | python -c 'import sys,base64; print(base64.b64decode(sys.stdin.read()).decode("utf-8","ignore"))' > "$TMP"
      chmod +x "$TMP"
      if [ -n "$CWD" ]; then
        OUT="$(cd "$CWD" && bash "$TMP" 2>&1 || true)"
      else
        OUT="$(bash "$TMP" 2>&1 || true)"
      fi
      # naive success heuristic
      echo "$OUT" | grep -qi "error\|not found\|traceback" && OK=false || OK=true
      [ "$OK" = "false" ] && ERR="shell task reported errors"
    fi
  else
    OK=false
    ERR="unsupported task_type"
  fi

  # report
  python - <<PY
import json,subprocess,sys
task_id=int("$TASK_ID")
ok=("$OK"=="true")
payload={
  "task_id": task_id,
  "ok": ok,
  "result": {"output": """$OUT"""[:8000]},
  "error": "$ERR"
}
import urllib.request
req=urllib.request.Request("http://127.0.0.1:8000/uul/tasks/report", data=json.dumps(payload).encode("utf-8"), headers={"Content-Type":"application/json"}, method="POST")
try:
  with urllib.request.urlopen(req, timeout=10) as r:
    print(r.read().decode("utf-8","ignore"))
except Exception as e:
  print("REPORT_FAILED", e)
PY

  sleep 1
done
SH
chmod +x "$ROOT/station_runner_loop4_uul.sh"

# =========================================================
# 8) DIGITAL EXECUTION + FINAL CHECK + GITHUB PUSH
# =========================================================
cat > "$DIG/run/digital_checks.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
echo "==[DIGITAL CHECKS]=="
echo "[tree]"; ls -la "$ROOT" | head
echo "[identity]"; ls -la "$ROOT/digital" | head
echo "[backend uul_core]"; ls -la "$ROOT/backend/uul_core" | head
echo "[health]"; curl -s http://127.0.0.1:8000/health || echo "backend not running"
echo
echo "[uul factory status]"; curl -s "http://127.0.0.1:8000/uul/factory/status?tail=40" || true
echo
SH
chmod +x "$DIG/run/digital_checks.sh"

cat > "$DIG/run/factory_smoke.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
echo "==[FACTORY SMOKE]=="
curl -s http://127.0.0.1:8000/health; echo
curl -s -X POST http://127.0.0.1:8000/uul/factory/run -H "x-edit-key: 1234"; echo
sleep 1
curl -s "http://127.0.0.1:8000/uul/factory/status?tail=200" | cat; echo
SH
chmod +x "$DIG/run/factory_smoke.sh"

cat > "$DIG/run/github_push.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
cd "$ROOT"
echo "==[GITHUB PUSH]=="
git status -sb || true
echo
echo "Run:"
echo "  git add -A"
echo "  git commit -m \"station: uul-extra digital factory v2\""
echo "  git push -u origin main"
SH
chmod +x "$DIG/run/github_push.sh"

# report
cat > "$DIG/out/REPORT_v2.md" <<'MD'
# Station – UUL-EXTRA Digital Factory Pack v2

## What is real now (not ideas)
- Digital identity files + chat tree + env matrix
- Backend module `uul_core` with:
  - /uul/factory/run
  - /uul/factory/status
  - /uul/tasks/submit
  - /uul/tasks/next
  - /uul/tasks/report
  - /uul/tasks/recent
- Runner Loop 4 script:
  - `station_runner_loop4_uul.sh` polls tasks and executes them locally, then reports results.

## Your "Loop" model (digital)
UI -> backend submit task -> Loop4 runner executes in Termux -> reports -> (next step Loop5 push GitHub) -> (Loop6 Render auto deploy)

## Next steps
1) Restart backend to load new routes
2) Run factory smoke
3) Start Loop4 runner
4) Submit tasks via /uul/tasks/submit (from UI or curl)
MD

say "DONE $(stamp)"
say "NEXT: restart backend then run: bash $DIG/run/factory_smoke.sh"
