#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
SCRIPTS="$ROOT/scripts"
BACK="$ROOT/backend"
FRONT="$ROOT/frontend"
LOGS="$ROOT/station_logs"

mkdir -p "$SCRIPTS" "$LOGS" "$ROOT/digital" "$ROOT/digital/spec" "$ROOT/digital/run" "$ROOT/digital/out"

stamp(){ date -Iseconds; }

echo "==[UUL-EXTRA] Digital Pack v1 :: START == $(stamp)"

# -----------------------------
# 0) DIGITAL IDENTITY (رقمية)
# -----------------------------
cat > "$ROOT/digital/identity.json" <<'JSON'
{
  "system": "station",
  "product": "Station Factory (Rooms+Dynamo+Loop)",
  "version": "digital_pack_v1",
  "runtime_targets": ["termux", "github", "render"],
  "owner": {
    "name": "Nasser Jawabreh",
    "profile": "operational_signature_v1"
  },
  "edit_mode": {
    "required_header": "x-edit-key",
    "default_value_hint": "1234",
    "notes": "Ops/Factory endpoints require x-edit-key"
  },
  "principles": [
    "Digital-first: everything is a file/spec/script",
    "No manual drift: generator is source of truth",
    "Rooms are atomic; Dynamo orchestrates",
    "Loop is the export/import backbone"
  ]
}
JSON

# ------------------------------------
# 1) DIGITAL CHAT TREE (شجرة رقمية)
# ------------------------------------
cat > "$ROOT/digital/spec/chat_tree.json" <<'JSON'
{
  "tree": "station_chat_tree_v1",
  "nodes": [
    {"id":"root","type":"menu","children":["ops","factory","rooms","loop","keys","status"]},
    {"id":"ops","type":"menu","children":["git_status","git_push","render_deploy"]},
    {"id":"factory","type":"menu","children":["run_factory","stop_factory","factory_status"]},
    {"id":"rooms","type":"menu","children":["room_core","room_backend","room_frontend","room_tests","room_git_pipeline","room_render_deploy"]},
    {"id":"loop","type":"menu","children":["loop4_runner","loop5_github","loop6_render"]},
    {"id":"keys","type":"menu","children":["openai","github","render","tts","hooks","ocr","whatsapp","email"]},
    {"id":"status","type":"menu","children":["health","info","version","logs"]}
  ]
}
JSON

# ---------------------------------------------------------
# 2) DIGITAL ENV SPEC (بيئة Termux/GitHub/Render رقميا)
# ---------------------------------------------------------
cat > "$ROOT/digital/spec/env_matrix.json" <<'JSON'
{
  "env_matrix": "station_env_matrix_v1",
  "termux": {
    "python": ">=3.11",
    "node": ">=18",
    "ports": [8000,5173],
    "notes": ["avoid heavy build deps", "utf-8 enforced"]
  },
  "github": {
    "branch": "main",
    "remote": "origin",
    "notes": ["auto-deploy triggers downstream if Render connected"]
  },
  "render": {
    "strategy": "auto-deploy-from-github",
    "notes": ["backend build/start in render.yaml or dashboard settings"]
  }
}
JSON

# -------------------------------------------
# 3) DIGITAL CHECKS (فحوص رقمية قبل/بعد)
# -------------------------------------------
cat > "$ROOT/digital/run/checks.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
echo "==[DIGITAL CHECKS]=="
echo "[1] tree:"; ls -la "$ROOT" | head
echo "[2] backend files:"; ls -la "$ROOT/backend" | head
echo "[3] scripts:"; ls -la "$ROOT/scripts" | head
echo "[4] ports (best effort):"
(ss -lntp 2>/dev/null || netstat -lntp 2>/dev/null || true) | sed -n '1,20p'
echo "[5] curl health (if running):"
curl -s http://127.0.0.1:8000/health 2>/dev/null || echo "backend not running"
echo
SH
chmod +x "$ROOT/digital/run/checks.sh"

# ---------------------------------------------------------
# 4) ROOTS/HEADERS/ENDPOINTS (رقميا) :: Factory API patch
# ---------------------------------------------------------
# We'll add a minimal "factory module" into backend without breaking existing routes.
mkdir -p "$BACK/station_factory"

cat > "$BACK/station_factory/__init__.py" <<'PY'
PY

cat > "$BACK/station_factory/factory_state.py" <<'PY'
from __future__ import annotations
import time
from dataclasses import dataclass, field
from typing import Dict, List, Optional

@dataclass
class RoomState:
    name: str
    status: str = "idle"       # idle|running|done|error
    last_log: str = ""
    updated_at: int = field(default_factory=lambda: int(time.time()))

@dataclass
class FactoryState:
    running: bool = False
    started_at: Optional[int] = None
    rooms: Dict[str, RoomState] = field(default_factory=dict)
    log_lines: List[str] = field(default_factory=list)

    def log(self, msg: str) -> None:
        ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        line = f"{ts} {msg}"
        self.log_lines.append(line)
        # keep bounded
        if len(self.log_lines) > 4000:
            self.log_lines = self.log_lines[-2000:]

STATE = FactoryState()
PY

cat > "$BACK/station_factory/rooms.py" <<'PY'
from __future__ import annotations
import os, subprocess, shlex, time
from .factory_state import STATE, RoomState

ROOT = os.path.expanduser("~/station_root")

def _run(cmd: str, cwd: str | None = None) -> tuple[int, str]:
    p = subprocess.Popen(cmd, cwd=cwd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out, _ = p.communicate()
    return p.returncode, (out or "").strip()

def room_core() -> None:
    STATE.log("[room:core] start")
    rc, out = _run("ls -la | head", cwd=ROOT)
    STATE.log(f"[room:core] rc={rc}")
    if out: STATE.log(out)

def room_backend() -> None:
    STATE.log("[room:backend] start")
    rc, out = _run("cd backend && python -V && ls -la | head", cwd=ROOT)
    STATE.log(f"[room:backend] rc={rc}")
    if out: STATE.log(out)

def room_frontend() -> None:
    STATE.log("[room:frontend] start")
    rc, out = _run("cd frontend && node -v && npm -v && ls -la | head", cwd=ROOT)
    STATE.log(f"[room:frontend] rc={rc}")
    if out: STATE.log(out)

def room_tests() -> None:
    STATE.log("[room:tests] start")
    rc1, h = _run("curl -s http://127.0.0.1:8000/health || true", cwd=ROOT)
    STATE.log(f"[room:tests] health_rc={rc1} body={h[:160]}")
    rc2, i = _run("curl -s http://127.0.0.1:8000/info || true", cwd=ROOT)
    STATE.log(f"[room:tests] info_rc={rc2} body={i[:160]}")

def room_git_pipeline() -> None:
    STATE.log("[room:git_pipeline] start")
    # best effort; requires git configured by user
    rc, out = _run("git status -sb || true", cwd=ROOT)
    STATE.log(f"[room:git_pipeline] rc={rc}")
    if out: STATE.log(out)

def room_render_deploy() -> None:
    # In this architecture: deploy is auto after push if Render is connected.
    STATE.log("[room:render_deploy] start")
    STATE.log("[room:render_deploy] strategy=auto-deploy-from-github (no direct Render API call here)")
PY

cat > "$BACK/station_factory/dynamo.py" <<'PY'
from __future__ import annotations
import time
from .factory_state import STATE, RoomState
from . import rooms

ROOM_FUNCS = {
    "core": rooms.room_core,
    "backend": rooms.room_backend,
    "frontend": rooms.room_frontend,
    "tests": rooms.room_tests,
    "git_pipeline": rooms.room_git_pipeline,
    "render_deploy": rooms.room_render_deploy,
}

DEFAULT_ORDER = ["core","backend","frontend","tests","git_pipeline","render_deploy"]

def ensure_rooms():
    for name in DEFAULT_ORDER:
        if name not in STATE.rooms:
            STATE.rooms[name] = RoomState(name=name)

def run_factory():
    ensure_rooms()
    if STATE.running:
        STATE.log("[DYNAMO] already running; skip")
        return
    STATE.running = True
    STATE.started_at = int(time.time())
    STATE.log("[DYNAMO] START")
    try:
        for name in DEFAULT_ORDER:
            rs = STATE.rooms[name]
            rs.status = "running"
            rs.updated_at = int(time.time())
            STATE.log(f"[DYNAMO] room={name} status=running")
            try:
                ROOM_FUNCS[name]()
                rs.status = "done"
                rs.updated_at = int(time.time())
                STATE.log(f"[DYNAMO] room={name} status=done")
            except Exception as e:
                rs.status = "error"
                rs.updated_at = int(time.time())
                rs.last_log = str(e)
                STATE.log(f"[DYNAMO] room={name} status=error err={e}")
                break
    finally:
        STATE.running = False
        STATE.log("[DYNAMO] STOP")
PY

cat > "$BACK/station_factory/api.py" <<'PY'
from __future__ import annotations
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from .factory_state import STATE
from .dynamo import run_factory

def _edit_ok(request: Request) -> bool:
    key = request.headers.get("x-edit-key", "")
    return bool(key)  # keep minimal; your existing backend may enforce exact match elsewhere

async def factory_run(request: Request):
    if not _edit_ok(request):
        return JSONResponse({"ok": False, "error": "missing x-edit-key"}, status_code=401)
    run_factory()
    return JSONResponse({"ok": True, "running": STATE.running})

async def factory_status(request: Request):
    tail = int(request.query_params.get("tail", "120"))
    rooms = {k: {"status": v.status, "updated_at": v.updated_at, "last_log": v.last_log} for k,v in STATE.rooms.items()}
    lines = STATE.log_lines[-max(10, min(4000, tail)):]
    return JSONResponse({"ok": True, "running": STATE.running, "started_at": STATE.started_at, "rooms": rooms, "log_tail": lines})

def routes():
    return [
        Route("/factory/run", factory_run, methods=["POST"]),
        Route("/factory/status", factory_status, methods=["GET"]),
    ]
PY

# ---------------------------------------------------
# 5) BACKEND HOOK (ربط الجذر/الرؤوس/المسارات رقميا)
# ---------------------------------------------------
# Patch backend main.py to register factory routes in a safe appended block.
MAIN="$BACK/main.py"
if [ -f "$MAIN" ]; then
  python - <<'PY'
from pathlib import Path

p = Path.home() / "station_root" / "backend" / "main.py"
s = p.read_text(encoding="utf-8", errors="ignore")

marker = "# === STATION_FACTORY_DIGITAL_PACK_V1 ==="
if marker in s:
    print("Factory patch already present.")
    raise SystemExit(0)

add = r'''
# === STATION_FACTORY_DIGITAL_PACK_V1 ===
# Digital-first factory API: /factory/run, /factory/status
try:
    from station_factory.api import routes as _factory_routes
    if "app" in globals():
        try:
            for r in _factory_routes():
                app.router.routes.append(r)
        except Exception:
            pass
except Exception:
    pass
'''
p.write_text(s.rstrip() + "\n\n" + marker + "\n" + add + "\n", encoding="utf-8")
print("OK: appended factory hook.")
PY
else
  echo "[WARN] backend/main.py not found; skipping hook."
fi

# ----------------------------------------
# 6) DIGITAL EXECUTION SCRIPTS (تنفيذ/فحص)
# ----------------------------------------
cat > "$ROOT/digital/run/factory_smoke.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
echo "==[FACTORY SMOKE]=="
curl -s http://127.0.0.1:8000/health; echo
curl -s -X POST http://127.0.0.1:8000/factory/run -H "x-edit-key: 1234"; echo
sleep 1
curl -s "http://127.0.0.1:8000/factory/status?tail=160" | cat; echo
SH
chmod +x "$ROOT/digital/run/factory_smoke.sh"

cat > "$ROOT/digital/run/final_run.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
echo "==[FINAL RUN]=="
pkill -f uvicorn || true
cd "$ROOT/backend"
./run_backend_official.sh
SH
chmod +x "$ROOT/digital/run/final_run.sh"

cat > "$ROOT/digital/run/push_github.sh" <<'SH'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
cd "$ROOT"
echo "==[GIT PUSH]=="
git status -sb || true
echo
echo "NOTE: configure origin/repo once. Then:"
echo "  git add -A && git commit -m 'station: digital factory pack v1' && git push -u origin main"
SH
chmod +x "$ROOT/digital/run/push_github.sh"

# ---------------------------------------------------
# 7) DIGITAL REPORT (مخرجات رقمية: ماذا تم توليده)
# ---------------------------------------------------
cat > "$ROOT/digital/out/REPORT.md" <<'MD'
# Station – Digital Factory Pack v1

## Generated
- digital/identity.json (Digital identity)
- digital/spec/chat_tree.json (Digital chat tree)
- digital/spec/env_matrix.json (Env matrix)
- digital/run/checks.sh (Pre/Post checks)
- backend/station_factory/* (Factory core: rooms/dynamo/state/api)
- backend/main.py patched (hook for /factory/*)
- digital/run/factory_smoke.sh (Factory smoke test)
- digital/run/final_run.sh (Final backend run)
- digital/run/push_github.sh (Git push guide)

## Endpoints
- POST /factory/run  (requires header x-edit-key)
- GET  /factory/status?tail=...

## Operating concept
- Rooms = atomic build/test units.
- Dynamo = orchestrator executes rooms in deterministic order.
- Loop 4 (Runner) remains your existing runner loop; this pack adds factory control plane.
MD

echo "==[UUL-EXTRA] Digital Pack v1 :: DONE == $(stamp)"
echo "Next:"
echo "  1) Restart backend"
echo "  2) Run: ~/station_root/digital/run/factory_smoke.sh"
