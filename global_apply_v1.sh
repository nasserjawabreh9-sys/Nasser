#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
BE="$ROOT/backend"
FE="$ROOT/frontend"
G="$ROOT/global"

mkdir -p "$G" "$G/templates" "$G/logs" "$ROOT/station_logs"

# ----------------------------
# G-001 Identity
# ----------------------------
cat > "$G/identity.json" <<'JSON'
{
  "product": "station",
  "method": "GLOBAL_DIGITAL_FACTORY_V1",
  "runtime": {
    "env": "termux",
    "backend_port": 8000,
    "frontend_port": 5173
  },
  "security": {
    "edit_key_header": "x-edit-key",
    "edit_key_env": "EDIT_MODE_KEY",
    "locks": true
  },
  "loops": ["loop4_runtime", "loop5_agent_runner", "loop6_publish"],
  "rooms": ["core", "backend", "frontend", "ops", "agent", "qa", "release"]
}
JSON

cat > "$G/runtime_state.json" <<'JSON'
{
  "time": null,
  "rooms": {},
  "dynamo": {
    "tick": 0,
    "last_tick": null,
    "alerts": []
  },
  "loops": {
    "loop4": {"status": "unknown"},
    "loop5": {"status": "unknown"},
    "loop6": {"status": "unknown"}
  }
}
JSON

cat > "$G/tree.json" <<'JSON'
{
  "root": "station_root",
  "paths": {
    "backend": "backend",
    "frontend": "frontend",
    "global": "global",
    "logs": "station_logs"
  },
  "backend": {
    "entry": "backend/main.py",
    "modules": [
      "backend/global_ops.py",
      "backend/global_rooms.py",
      "backend/global_dynamo.py",
      "backend/global_guards.py"
    ]
  },
  "scripts": [
    "station_runner_loop.sh",
    "global/loop5_agent_runner.sh",
    "global/loop6_publish.sh",
    "global/smoke.sh",
    "global/release.sh"
  ]
}
JSON

cat > "$G/manifest.json" <<'JSON'
{
  "version": "GLOBAL_V1",
  "deliverables": [
    "G-001 Identity",
    "G-010 Tree",
    "G-020 Guards",
    "G-030 Rooms",
    "G-040 Dynamo",
    "G-050 Loops 4/5/6",
    "G-060 Ops API",
    "G-090 Smoke/Release"
  ]
}
JSON

# ----------------------------
# G-020 Guards (locks + key guard)
# ----------------------------
cat > "$BE/global_guards.py" <<'PY'
import os
import time
from pathlib import Path
from typing import Optional

LOCK_DIR = Path(os.environ.get("STATION_LOCK_DIR", str(Path.home() / "station_root" / "global" / "locks")))
LOCK_DIR.mkdir(parents=True, exist_ok=True)

def require_edit_key(headers) -> Optional[str]:
    key = os.environ.get("EDIT_MODE_KEY", "1234")
    got = headers.get("x-edit-key") or headers.get("X-Edit-Key")
    if not got or got != key:
        return "unauthorized"
    return None

def lock_path(name: str) -> Path:
    return LOCK_DIR / f"{name}.lock"

def try_lock(name: str, ttl_sec: int = 120) -> bool:
    p = lock_path(name)
    now = int(time.time())
    if p.exists():
        try:
            ts = int(p.read_text().strip() or "0")
        except Exception:
            ts = 0
        if now - ts < ttl_sec:
            return False
    p.write_text(str(now))
    return True

def unlock(name: str) -> None:
    p = lock_path(name)
    try:
        p.unlink(missing_ok=True)
    except Exception:
        pass
PY

# ----------------------------
# G-060 Ops API (git status/push + render deploy placeholder)
# ----------------------------
cat > "$BE/global_ops.py" <<'PY'
import os
import json
import subprocess
from pathlib import Path
from starlette.responses import JSONResponse
from starlette.requests import Request
from .global_guards import require_edit_key, try_lock, unlock

ROOT = Path(os.environ.get("STATION_ROOT", str(Path.home() / "station_root")))

def _run(cmd, cwd=None):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, shell=False)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

async def ops_git_status(request: Request):
    err = require_edit_key(request.headers)
    if err:
        return JSONResponse({"ok": False, "error": err}, status_code=401)

    if not try_lock("ops_git_status", ttl_sec=10):
        return JSONResponse({"ok": False, "error": "locked"}, status_code=423)

    try:
        code, out, e = _run(["git", "status", "--porcelain", "-b"], cwd=str(ROOT))
        return JSONResponse({"ok": code == 0, "code": code, "stdout": out, "stderr": e})
    finally:
        unlock("ops_git_status")

async def ops_git_push(request: Request):
    err = require_edit_key(request.headers)
    if err:
        return JSONResponse({"ok": False, "error": err}, status_code=401)

    if not try_lock("ops_git_push", ttl_sec=120):
        return JSONResponse({"ok": False, "error": "locked"}, status_code=423)

    try:
        body = await request.json()
        msg = (body.get("message") or "GLOBAL: update").strip()

        code1, out1, e1 = _run(["git", "add", "-A"], cwd=str(ROOT))
        code2, out2, e2 = _run(["git", "commit", "-m", msg], cwd=str(ROOT))
        # commit might fail if no changes
        code3, out3, e3 = _run(["git", "push", "-u", "origin", "main"], cwd=str(ROOT))

        return JSONResponse({
            "ok": code3 == 0,
            "steps": {
                "add": {"code": code1, "stdout": out1, "stderr": e1},
                "commit": {"code": code2, "stdout": out2, "stderr": e2},
                "push": {"code": code3, "stdout": out3, "stderr": e3}
            }
        })
    finally:
        unlock("ops_git_push")

async def ops_render_deploy(request: Request):
    err = require_edit_key(request.headers)
    if err:
        return JSONResponse({"ok": False, "error": err}, status_code=401)

    if not try_lock("ops_render_deploy", ttl_sec=300):
        return JSONResponse({"ok": False, "error": "locked"}, status_code=423)

    try:
        # Placeholder: in Render, deploy is typically triggered by Git push.
        # If you have Render Deploy Hook URL, store it in env: RENDER_DEPLOY_HOOK_URL
        hook = os.environ.get("RENDER_DEPLOY_HOOK_URL", "").strip()
        if not hook:
            return JSONResponse({"ok": False, "error": "missing_render_deploy_hook_url"}, status_code=400)

        # Use curl if available
        code, out, e = _run(["curl", "-sS", "-X", "POST", hook], cwd=str(ROOT))
        return JSONResponse({"ok": code == 0, "code": code, "stdout": out, "stderr": e})
    finally:
        unlock("ops_render_deploy")
PY

# ----------------------------
# G-030 Rooms Engine
# ----------------------------
cat > "$BE/global_rooms.py" <<'PY'
import time
import json
from pathlib import Path
from starlette.responses import JSONResponse
from starlette.requests import Request
from .global_guards import require_edit_key

ROOT = Path.home() / "station_root"
STATE = ROOT / "global" / "runtime_state.json"

DEFAULT_ROOMS = {
    "core": {"status": "idle", "last": None},
    "backend": {"status": "idle", "last": None},
    "frontend": {"status": "idle", "last": None},
    "ops": {"status": "idle", "last": None},
    "agent": {"status": "idle", "last": None},
    "qa": {"status": "idle", "last": None},
    "release": {"status": "idle", "last": None}
}

def _load():
    if not STATE.exists():
        return {"rooms": DEFAULT_ROOMS, "dynamo": {"tick": 0, "alerts": []}, "loops": {}}
    try:
        return json.loads(STATE.read_text(encoding="utf-8"))
    except Exception:
        return {"rooms": DEFAULT_ROOMS, "dynamo": {"tick": 0, "alerts": []}, "loops": {}}

def _save(s):
    s["time"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    STATE.write_text(json.dumps(s, indent=2), encoding="utf-8")

async def rooms_get(request: Request):
    s = _load()
    if "rooms" not in s:
        s["rooms"] = DEFAULT_ROOMS
        _save(s)
    return JSONResponse({"ok": True, "rooms": s["rooms"], "time": s.get("time")})

async def rooms_update(request: Request):
    err = require_edit_key(request.headers)
    if err:
        return JSONResponse({"ok": False, "error": err}, status_code=401)

    body = await request.json()
    name = (body.get("name") or "").strip()
    status = (body.get("status") or "").strip()
    note = (body.get("note") or "").strip()

    if not name or name not in DEFAULT_ROOMS:
        return JSONResponse({"ok": False, "error": "invalid_room"}, status_code=400)

    s = _load()
    s.setdefault("rooms", DEFAULT_ROOMS)
    s["rooms"].setdefault(name, {"status": "idle", "last": None})
    s["rooms"][name]["status"] = status or s["rooms"][name]["status"]
    s["rooms"][name]["last"] = {"ts": int(time.time()), "note": note}
    _save(s)
    return JSONResponse({"ok": True, "room": {name: s["rooms"][name]}})
PY

# ----------------------------
# G-040 Dynamo
# ----------------------------
cat > "$BE/global_dynamo.py" <<'PY'
import time
import json
from pathlib import Path
from starlette.responses import JSONResponse
from starlette.requests import Request
from .global_guards import require_edit_key

ROOT = Path.home() / "station_root"
STATE = ROOT / "global" / "runtime_state.json"

def _load():
    if not STATE.exists():
        return {"dynamo": {"tick": 0, "alerts": []}, "rooms": {}, "loops": {}}
    try:
        return json.loads(STATE.read_text(encoding="utf-8"))
    except Exception:
        return {"dynamo": {"tick": 0, "alerts": []}, "rooms": {}, "loops": {}}

def _save(s):
    s["time"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    STATE.write_text(json.dumps(s, indent=2), encoding="utf-8")

async def dynamo_tick(request: Request):
    err = require_edit_key(request.headers)
    if err:
        return JSONResponse({"ok": False, "error": err}, status_code=401)

    s = _load()
    s.setdefault("dynamo", {"tick": 0, "alerts": []})
    s["dynamo"]["tick"] = int(s["dynamo"].get("tick", 0)) + 1
    s["dynamo"]["last_tick"] = int(time.time())
    _save(s)
    return JSONResponse({"ok": True, "tick": s["dynamo"]["tick"], "last_tick": s["dynamo"]["last_tick"]})

async def dynamo_alert(request: Request):
    err = require_edit_key(request.headers)
    if err:
        return JSONResponse({"ok": False, "error": err}, status_code=401)

    body = await request.json()
    msg = (body.get("message") or "").strip()
    level = (body.get("level") or "info").strip()

    if not msg:
        return JSONResponse({"ok": False, "error": "missing_message"}, status_code=400)

    s = _load()
    s.setdefault("dynamo", {"tick": 0, "alerts": []})
    s["dynamo"].setdefault("alerts", [])
    s["dynamo"]["alerts"].append({"ts": int(time.time()), "level": level, "message": msg})
    s["dynamo"]["alerts"] = s["dynamo"]["alerts"][-50:]
    _save(s)
    return JSONResponse({"ok": True, "alerts": s["dynamo"]["alerts"]})
PY

# ----------------------------
# Inject routes into backend/main.py (safe append)
# ----------------------------
python - <<'PY'
from pathlib import Path
import re

p = Path.home() / "station_root" / "backend" / "main.py"
s = p.read_text(encoding="utf-8", errors="ignore")

marker = "# === GLOBAL_V1_ROUTES ==="
if marker in s:
    print("GLOBAL routes already present. Skipping inject.")
    raise SystemExit(0)

inject = r'''
# === GLOBAL_V1_ROUTES ===
# Digital Factory: Ops + Rooms + Dynamo routes (English only)
try:
    from backend.global_ops import ops_git_status, ops_git_push, ops_render_deploy
    from backend.global_rooms import rooms_get, rooms_update
    from backend.global_dynamo import dynamo_tick, dynamo_alert

    if "app" in globals():
        try:
            app.add_route("/ops/git/status", ops_git_status, methods=["POST"])
            app.add_route("/ops/git/push", ops_git_push, methods=["POST"])
            app.add_route("/ops/render/deploy", ops_render_deploy, methods=["POST"])

            app.add_route("/global/rooms", rooms_get, methods=["GET"])
            app.add_route("/global/rooms/update", rooms_update, methods=["POST"])

            app.add_route("/global/dynamo/tick", dynamo_tick, methods=["POST"])
            app.add_route("/global/dynamo/alert", dynamo_alert, methods=["POST"])
        except Exception:
            pass
except Exception:
    pass
'''

p.write_text(s.rstrip() + "\n\n" + marker + "\n" + inject + "\n", encoding="utf-8")
print("OK: injected GLOBAL routes into main.py")
PY

# ----------------------------
# G-050 Loop 5 (Agent runner) - practical local runner
# This runner will call /agent/tasks/recent and attempt to execute queued tasks via local shell
# If your backend already executes tasks internally later, this runner is still safe.
# ----------------------------
cat > "$G/loop5_agent_runner.sh" <<'BASH2'
#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
ENV="$ROOT/station_env.sh"
LOG="$ROOT/global/logs/loop5_agent_runner.log"
API="http://127.0.0.1:8000"
EDIT="${EDIT_MODE_KEY:-1234}"

mkdir -p "$(dirname "$LOG")"

source "$ENV" || true

echo "==== LOOP5 START $(date -Iseconds) ====" | tee -a "$LOG"

while true; do
  JSON=$(curl -s "$API/agent/tasks/recent?limit=10" -H "x-edit-key: $EDIT" || true)

  # Extract queued tasks with python (Termux-safe)
  python - <<'PY' "$JSON" "$ROOT" "$LOG"
import sys, json, base64, os, subprocess, time
data_raw = sys.argv[1]
root = sys.argv[2]
log = sys.argv[3]

def w(msg):
    with open(log, "a", encoding="utf-8") as f:
        f.write(msg + "\n")

try:
    data = json.loads(data_raw) if data_raw else {}
except Exception:
    data = {}

items = data.get("items") or []
queued = [it for it in items if (it.get("status") == "queued") and (it.get("task_type") == "shell")]

if not queued:
    sys.exit(0)

# Best-effort: execute ONLY the newest queued task to reduce concurrency risk
it = queued[0]
tid = it.get("id")
payload = it.get("payload") or {}
cwd = payload.get("cwd") or root
b64 = payload.get("script_b64") or ""
try:
    script = base64.b64decode(b64).decode("utf-8", "ignore")
except Exception:
    script = ""

if not script.strip():
    w(f"[loop5] task {tid} missing script")
    sys.exit(0)

tmp = os.path.join(root, "global", "tmp_task.sh")
os.makedirs(os.path.dirname(tmp), exist_ok=True)
with open(tmp, "w", encoding="utf-8") as f:
    f.write(script + "\n")
os.chmod(tmp, 0o755)

w(f"[loop5] executing task {tid} in {cwd}")
p = subprocess.run([tmp], cwd=cwd, capture_output=True, text=True)
w(f"[loop5] task {tid} rc={p.returncode}")
if p.stdout:
    w("[loop5] stdout:\n" + p.stdout.strip())
if p.stderr:
    w("[loop5] stderr:\n" + p.stderr.strip())
PY

  sleep 2
done
BASH2
chmod +x "$G/loop5_agent_runner.sh"

# ----------------------------
# G-050 Loop 6 (Publish loop) - push + optional render deploy hook
# ----------------------------
cat > "$G/loop6_publish.sh" <<'BASH3'
#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
ENV="$ROOT/station_env.sh"
LOG="$ROOT/global/logs/loop6_publish.log"

source "$ENV" || true

echo "==== LOOP6 START $(date -Iseconds) ====" | tee -a "$LOG"

cd "$ROOT"
git status --porcelain -b | tee -a "$LOG" || true

git add -A | tee -a "$LOG" || true
git commit -m "GLOBAL: publish" | tee -a "$LOG" || true
git push -u origin main | tee -a "$LOG"

if [ -n "${RENDER_DEPLOY_HOOK_URL:-}" ]; then
  curl -sS -X POST "$RENDER_DEPLOY_HOOK_URL" | tee -a "$LOG" || true
fi

echo "==== LOOP6 DONE ====" | tee -a "$LOG"
BASH3
chmod +x "$G/loop6_publish.sh"

# ----------------------------
# G-090 Smoke + Release
# ----------------------------
cat > "$G/smoke.sh" <<'SMOKE'
#!/data/data/com.termux/files/usr/bin/bash
set -e
API="http://127.0.0.1:8000"
echo "== health =="; curl -s "$API/health"; echo
echo "== info =="; curl -s "$API/info"; echo
echo "== version =="; curl -s "$API/version"; echo
echo "== global rooms =="; curl -s "$API/global/rooms"; echo
SMOKE
chmod +x "$G/smoke.sh"

cat > "$G/release.sh" <<'REL'
#!/data/data/com.termux/files/usr/bin/bash
set -e
ROOT="$HOME/station_root"
echo "== smoke =="
"$ROOT/global/smoke.sh"
echo "== publish =="
"$ROOT/global/loop6_publish.sh"
REL
chmod +x "$G/release.sh"

echo
echo "GLOBAL APPLY V1: DONE"
echo "Next:"
echo "  1) Restart backend"
echo "  2) Run smoke"
echo "  3) Start loop5 if you want task execution"
