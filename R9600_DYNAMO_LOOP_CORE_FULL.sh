#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9600] Dynamo Loop Core + Settings Store + Ops RunCmd @ $ROOT"

# -----------------------------
# 0) Ensure dirs
# -----------------------------
mkdir -p station_meta/queue station_meta/settings station_meta/logs
mkdir -p backend/app/routes
touch backend/app/__init__.py backend/app/routes/__init__.py

# -----------------------------
# 1) Settings store (runtime keys) - JSON file
# -----------------------------
SETTINGS_PATH="station_meta/settings/runtime_keys.json"
if [ ! -f "$SETTINGS_PATH" ]; then
  cat > "$SETTINGS_PATH" <<'JSON'
{
  "keys": {
    "openai_api_key": "",
    "github_token": "",
    "render_api_key": "",
    "google_api_key": "",
    "tts_key": "",
    "ocr_key": "",
    "webhooks_url": "",
    "whatsapp_token": "",
    "email_smtp": "",
    "edit_mode_key": "1234"
  }
}
JSON
fi

cat > backend/app/settings_store.py <<'PY'
import os, json, time
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
SETTINGS_PATH = ROOT_DIR / "station_meta" / "settings" / "runtime_keys.json"

DEFAULTS = {
  "openai_api_key": "",
  "github_token": "",
  "render_api_key": "",
  "google_api_key": "",
  "tts_key": "",
  "ocr_key": "",
  "webhooks_url": "",
  "whatsapp_token": "",
  "email_smtp": "",
  "edit_mode_key": "1234"
}

ENV_MAP = {
  "openai_api_key": ["STATION_OPENAI_API_KEY", "OPENAI_API_KEY"],
  "github_token": ["GITHUB_TOKEN"],
  "render_api_key": ["RENDER_API_KEY"],
  "google_api_key": ["GOOGLE_API_KEY"],
  "tts_key": ["TTS_KEY"],
  "ocr_key": ["OCR_KEY"],
  "webhooks_url": ["WEBHOOKS_URL"],
  "whatsapp_token": ["WHATSAPP_TOKEN", "WHATSAPP_KEY"],
  "email_smtp": ["EMAIL_SMTP"],
  "edit_mode_key": ["STATION_EDIT_KEY", "EDIT_MODE_KEY"]
}

def _ensure():
  if SETTINGS_PATH.exists():
    return
  SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
  SETTINGS_PATH.write_text(json.dumps({"keys": DEFAULTS, "ts": time.time()}, indent=2), encoding="utf-8")

def _read_file() -> dict:
  _ensure()
  try:
    j = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
    keys = (j.get("keys") or {})
    return keys if isinstance(keys, dict) else {}
  except Exception:
    return {}

def merged_keys() -> dict:
  _ensure()
  keys = dict(DEFAULTS)
  keys.update(_read_file())

  # env overrides
  for k, envs in ENV_MAP.items():
    for env in envs:
      v = (os.getenv(env) or "").strip()
      if v:
        keys[k] = v
        break

  keys["edit_mode_key"] = (keys.get("edit_mode_key") or "1234").strip() or "1234"
  return keys

def expected_edit_key() -> str:
  return merged_keys().get("edit_mode_key", "1234").strip() or "1234"

def write_keys(new_keys: dict) -> dict:
  _ensure()
  base = merged_keys()
  allow = set(DEFAULTS.keys())
  for k, v in (new_keys or {}).items():
    if k in allow:
      base[k] = "" if v is None else str(v)
  SETTINGS_PATH.write_text(json.dumps({"keys": base, "ts": time.time()}, indent=2), encoding="utf-8")
  return base
PY

cat > backend/app/routes/settings.py <<'PY'
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.settings_store import merged_keys, write_keys, expected_edit_key

def _auth_ok(request: Request) -> bool:
  got = (request.headers.get("X-Edit-Key") or "").strip()
  return got != "" and got == expected_edit_key()

async def get_settings(request: Request):
  return JSONResponse({"ok": True, "keys": merged_keys()})

async def set_settings(request: Request):
  if not _auth_ok(request):
    return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)
  body = {}
  try:
    body = await request.json()
  except Exception:
    body = {}
  keys = (body.get("keys") or {})
  merged = write_keys(keys)
  return JSONResponse({"ok": True, "keys": merged})

routes = [
  Route("/api/settings", get_settings, methods=["GET"]),
  Route("/api/settings", set_settings, methods=["POST"]),
]
PY

# -----------------------------
# 2) Dynamo Queue + Worker (JSONL)
# -----------------------------
cat > backend/app/loop_queue.py <<'PY'
import json, time, os, uuid
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
QUEUE_DIR = ROOT_DIR / "station_meta" / "queue"
TASKS_JL = QUEUE_DIR / "tasks.jsonl"
LOCK_DIR = QUEUE_DIR / "locks"
LOG_DIR  = ROOT_DIR / "station_meta" / "logs"

def _ensure():
  QUEUE_DIR.mkdir(parents=True, exist_ok=True)
  LOCK_DIR.mkdir(parents=True, exist_ok=True)
  LOG_DIR.mkdir(parents=True, exist_ok=True)
  if not TASKS_JL.exists():
    TASKS_JL.write_text("", encoding="utf-8")

def now() -> float:
  return time.time()

def _append(rec: dict):
  _ensure()
  with TASKS_JL.open("a", encoding="utf-8") as f:
    f.write(json.dumps(rec, ensure_ascii=False) + "\n")

def submit(kind: str, payload: dict, max_retries: int = 3) -> dict:
  tid = str(uuid.uuid4())
  rec = {
    "id": tid,
    "kind": kind,
    "payload": payload or {},
    "status": "pending",
    "created_at": now(),
    "updated_at": now(),
    "tries": 0,
    "max_retries": int(max_retries),
    "last_error": ""
  }
  _append(rec)
  return rec

def list_tail(limit: int = 200) -> list[dict]:
  _ensure()
  try:
    lines = TASKS_JL.read_text(encoding="utf-8").splitlines()
  except Exception:
    return []
  out = []
  for ln in lines[-limit:]:
    try:
      out.append(json.loads(ln))
    except Exception:
      pass
  return out

def _lock_path(tid: str) -> Path:
  return LOCK_DIR / f"{tid}.lock"

def try_lock(tid: str) -> bool:
  _ensure()
  p = _lock_path(tid)
  try:
    fd = os.open(str(p), os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    os.write(fd, str(os.getpid()).encode("utf-8"))
    os.close(fd)
    return True
  except Exception:
    return False

def unlock(tid: str):
  try:
    _lock_path(tid).unlink(missing_ok=True)  # py3.11+
  except Exception:
    pass

def log_line(msg: str):
  _ensure()
  p = LOG_DIR / "dynamo_worker.log"
  with p.open("a", encoding="utf-8") as f:
    f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {msg}\n")
PY

cat > backend/app/loop_worker.py <<'PY'
import json, time, traceback
from pathlib import Path

from app.loop_queue import TASKS_JL, list_tail, try_lock, unlock, log_line, now

ROOT_DIR = Path(__file__).resolve().parents[2]

def _read_all() -> list[dict]:
  try:
    lines = TASKS_JL.read_text(encoding="utf-8").splitlines()
  except Exception:
    return []
  out = []
  for ln in lines:
    try:
      out.append(json.loads(ln))
    except Exception:
      pass
  return out

def _write_all(records: list[dict]):
  TASKS_JL.write_text("\n".join(json.dumps(r, ensure_ascii=False) for r in records) + ("\n" if records else ""), encoding="utf-8")

def _pick_next(records: list[dict]) -> dict|None:
  # first pending or failed with retries left
  for r in records:
    if r.get("status") == "pending":
      return r
  for r in records:
    if r.get("status") == "failed" and int(r.get("tries", 0)) < int(r.get("max_retries", 0)):
      return r
  return None

def _backoff_seconds(tries: int) -> float:
  # exponential backoff: 1,2,4,8... capped 20
  return min(20.0, float(2 ** max(0, tries)))

def _execute_task(task: dict) -> dict:
  kind = (task.get("kind") or "").strip()
  payload = task.get("payload") or {}

  # Extend here later: git ops, render ops, llm ops, etc.
  if kind == "ping":
    return {"ok": True, "kind": "ping", "ts": now(), "payload": payload}

  if kind == "echo":
    return {"ok": True, "kind": "echo", "payload": payload}

  # unknown
  return {"ok": False, "error": "unknown_task_kind", "kind": kind, "payload": payload}

def run_once() -> dict:
  records = _read_all()
  task = _pick_next(records)
  if not task:
    return {"ok": True, "message": "no_tasks"}

  tid = task["id"]
  if not try_lock(tid):
    return {"ok": True, "message": "locked_skip", "task_id": tid}

  try:
    # backoff if retrying
    tries = int(task.get("tries", 0))
    if task.get("status") == "failed" and tries > 0:
      time.sleep(_backoff_seconds(tries))

    # mark running
    for r in records:
      if r.get("id") == tid:
        r["status"] = "running"
        r["updated_at"] = now()
    _write_all(records)

    # execute
    res = _execute_task(task)

    # mark done/failed
    records = _read_all()
    for r in records:
      if r.get("id") == tid:
        r["tries"] = int(r.get("tries", 0)) + 1
        r["updated_at"] = now()
        if res.get("ok"):
          r["status"] = "done"
          r["result"] = res
          r["last_error"] = ""
        else:
          r["status"] = "failed"
          r["result"] = res
          r["last_error"] = str(res.get("error") or "failed")
    _write_all(records)

    log_line(f"[RUN] {tid} kind={task.get('kind')} status={'done' if res.get('ok') else 'failed'}")
    return {"ok": True, "task_id": tid, "result": res}

  except Exception as e:
    records = _read_all()
    for r in records:
      if r.get("id") == tid:
        r["tries"] = int(r.get("tries", 0)) + 1
        r["updated_at"] = now()
        r["status"] = "failed"
        r["last_error"] = str(e)
        r["result"] = {"ok": False, "error": str(e), "trace": traceback.format_exc()}
    _write_all(records)
    log_line(f"[ERR] {tid} {e}")
    return {"ok": False, "task_id": tid, "error": str(e)}

  finally:
    unlock(tid)

def daemon_loop(interval_sec: float = 2.0):
  log_line("[BOOT] dynamo_worker started")
  while True:
    run_once()
    time.sleep(max(0.5, float(interval_sec)))
PY

# -----------------------------
# 3) Loop API routes
# -----------------------------
cat > backend/app/routes/loop.py <<'PY'
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route

from app.loop_queue import submit, list_tail
from app.loop_worker import run_once

async def post_task(request: Request):
  body = {}
  try:
    body = await request.json()
  except Exception:
    body = {}
  kind = (body.get("kind") or "ping").strip()
  payload = body.get("payload") or {}
  max_retries = int(body.get("max_retries") or 3)
  rec = submit(kind, payload, max_retries=max_retries)
  return JSONResponse({"ok": True, "task": rec})

async def get_tasks(request: Request):
  limit = int(request.query_params.get("limit") or 200)
  items = list_tail(limit)
  return JSONResponse({"ok": True, "items": items})

async def run_once_api(request: Request):
  res = run_once()
  return JSONResponse({"ok": True, "run": res})

routes = [
  Route("/api/loop/task", post_task, methods=["POST"]),
  Route("/api/loop/tasks", get_tasks, methods=["GET"]),
  Route("/api/loop/run_once", run_once_api, methods=["POST"]),
]
PY

# -----------------------------
# 4) Ops RunCmd (limited + protected by X-Edit-Key)
# -----------------------------
cat > backend/app/routes/ops_run_cmd.py <<'PY'
import subprocess
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.settings_store import expected_edit_key

ALLOWED = {
  "pwd": ["pwd"],
  "ls":  ["ls", "-la"],
  "git_status": ["git", "status"],
  "git_log": ["git", "log", "--oneline", "-n", "20"]
}

def _auth_ok(request: Request) -> bool:
  got = (request.headers.get("X-Edit-Key") or "").strip()
  return got != "" and got == expected_edit_key()

async def run_cmd(request: Request):
  if not _auth_ok(request):
    return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)

  body = {}
  try:
    body = await request.json()
  except Exception:
    body = {}

  cmd_key = (body.get("cmd") or "").strip()
  if cmd_key not in ALLOWED:
    return JSONResponse({"ok": False, "error": "cmd_not_allowed", "allowed": list(ALLOWED.keys())}, status_code=400)

  try:
    p = subprocess.run(
      ALLOWED[cmd_key],
      capture_output=True,
      text=True,
      cwd=str((__import__("pathlib").Path(__file__).resolve().parents[3]))
    )
    return JSONResponse({
      "ok": True,
      "cmd": cmd_key,
      "returncode": p.returncode,
      "stdout": p.stdout[-4000:],
      "stderr": p.stderr[-4000:]
    })
  except Exception as e:
    return JSONResponse({"ok": False, "error": str(e)}, status_code=500)

routes = [
  Route("/api/ops/run_cmd", run_cmd, methods=["POST"]),
]
PY

# -----------------------------
# 5) Patch backend/app/main.py to include routes
# -----------------------------
python - <<'PY'
from pathlib import Path
import re

p = Path("backend/app/main.py")
txt = p.read_text(encoding="utf-8")

def ensure_import(modline: str):
  global txt
  if modline in txt:
    return
  m = re.search(r"from\s+starlette\.routing\s+import\s+Route.*", txt)
  if m:
    txt = txt.replace(m.group(0), m.group(0) + "\n" + modline, 1)
  else:
    txt = modline + "\n" + txt

ensure_import("from app.routes import settings")
ensure_import("from app.routes import loop")
ensure_import("from app.routes import ops_run_cmd")

if re.search(r"routes\s*=\s*\[", txt) is None:
  raise SystemExit("main.py has no routes=[...] list; cannot patch safely.")

def inject_once(marker: str, line: str):
  global txt
  if marker in txt:
    return
  txt = re.sub(r"routes\s*=\s*\[", "routes = [\n" + line, txt, count=1)

inject_once("/api/settings", "    *settings.routes,\n")
inject_once("/api/loop/task", "    *loop.routes,\n")
inject_once("/api/ops/run_cmd", "    *ops_run_cmd.routes,\n")

p.write_text(txt, encoding="utf-8")
print("OK: main.py wired settings + loop + ops_run_cmd")
PY

# -----------------------------
# 6) Ops scripts: loop start/stop/status/verify
# -----------------------------
mkdir -p scripts/ops

cat > scripts/ops/loop_start.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
cd "$ROOT"

PIDFILE="station_meta/queue/dynamo_worker.pid"
LOGFILE="station_meta/logs/dynamo_worker.log"

# kill stale if exists
if [ -f "$PIDFILE" ]; then
  OLD="$(cat "$PIDFILE" || true)"
  if [ -n "$OLD" ]; then
    kill "$OLD" >/dev/null 2>&1 || true
  fi
  rm -f "$PIDFILE"
fi

cd "$ROOT/backend"
source .venv/bin/activate

nohup python - <<'PY' >> "../$LOGFILE" 2>&1 &
from app.loop_worker import daemon_loop
daemon_loop(interval_sec=2.0)
PY

echo $! > "../$PIDFILE"
echo "OK: dynamo_worker started pid=$(cat ../$PIDFILE)"
echo "LOG: $LOGFILE"
EOF
chmod +x scripts/ops/loop_start.sh

cat > scripts/ops/loop_stop.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
PIDFILE="$ROOT/station_meta/queue/dynamo_worker.pid"
if [ ! -f "$PIDFILE" ]; then
  echo "OK: no pidfile"
  exit 0
fi
PID="$(cat "$PIDFILE" || true)"
if [ -n "$PID" ]; then
  kill "$PID" >/dev/null 2>&1 || true
fi
rm -f "$PIDFILE"
echo "OK: stopped"
EOF
chmod +x scripts/ops/loop_stop.sh

cat > scripts/ops/loop_status.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
PIDFILE="$ROOT/station_meta/queue/dynamo_worker.pid"
if [ ! -f "$PIDFILE" ]; then
  echo "STATUS: stopped"
  exit 0
fi
PID="$(cat "$PIDFILE" || true)"
if [ -z "$PID" ]; then
  echo "STATUS: stopped (empty pidfile)"
  exit 0
fi
if kill -0 "$PID" >/dev/null 2>&1; then
  echo "STATUS: running pid=$PID"
else
  echo "STATUS: stale pidfile (pid not running)"
fi
EOF
chmod +x scripts/ops/loop_status.sh

cat > scripts/ops/verify_loop_e2e.sh <<'EOF'
#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "=== HEALTH ==="
curl -sS http://127.0.0.1:8000/health && echo

echo
echo "=== SETTINGS (GET /api/settings) ==="
curl -sS http://127.0.0.1:8000/api/settings | head -c 600 && echo

echo
echo "=== LOOP: submit task ==="
curl -sS -X POST http://127.0.0.1:8000/api/loop/task \
  -H "Content-Type: application/json" \
  -d '{"kind":"echo","payload":{"msg":"hello_loop"}}' && echo

echo
echo "=== LOOP: run once ==="
curl -sS -X POST http://127.0.0.1:8000/api/loop/run_once && echo

echo
echo "=== LOOP: list tasks tail ==="
curl -sS "http://127.0.0.1:8000/api/loop/tasks?limit=20" | head -c 900 && echo

echo
echo "DONE."
EOF
chmod +x scripts/ops/verify_loop_e2e.sh

# -----------------------------
# 7) Ensure backend requirements minimal (no heavy deps)
# -----------------------------
REQ="backend/requirements.txt"
grep -q "^requests==" "$REQ" 2>/dev/null || echo "requests==2.31.0" >> "$REQ"

echo ">>> [R9600] DONE."
echo "Next steps:"
echo "  1) cd $ROOT/backend && source .venv/bin/activate && python -m pip install -r requirements.txt"
echo "  2) HARD restart Station: bash R9500_HARD_RESTART_FIX_NOTFOUND.sh"
echo "  3) Start loop: bash scripts/ops/loop_start.sh"
echo "  4) Verify:    bash scripts/ops/verify_loop_e2e.sh"
echo "  5) Status:    bash scripts/ops/loop_status.sh"
