#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT_DIR="$(pwd)"
mkdir -p backend/app/routes station_meta/bindings

# 1) Ensure backend routes package
touch backend/app/__init__.py backend/app/routes/__init__.py

# 2) Create uui_config route (GET/POST)
cat > backend/app/routes/uui_config.py <<'PY'
import os, json
from starlette.responses import JSONResponse
from starlette.requests import Request

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
UUI_STORE = os.path.abspath(os.path.join(ROOT_DIR, "station_meta", "bindings", "uui_config.json"))

DEFAULT_KEYS = {
    "openai_api_key": "",
    "github_token": "",
    "tts_key": "",
    "webhooks_url": "",
    "ocr_key": "",
    "web_integration_key": "",
    "whatsapp_key": "",
    "email_smtp": "",
    "github_repo": "",
    "render_api_key": "",
    "edit_mode_key": "1234"
}

def _read_cfg():
    try:
        with open(UUI_STORE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        keys = (cfg.get("keys") or {})
        return {"keys": {**DEFAULT_KEYS, **keys}}
    except Exception:
        return {"keys": dict(DEFAULT_KEYS)}

def _write_cfg(keys: dict):
    os.makedirs(os.path.dirname(UUI_STORE), exist_ok=True)
    cfg = {"keys": {**DEFAULT_KEYS, **(keys or {})}}
    with open(UUI_STORE, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    return cfg

def _edit_key_expected():
    envk = (os.getenv("STATION_EDIT_KEY") or "").strip()
    if envk:
        return envk
    cfg = _read_cfg()
    k = ((cfg.get("keys") or {}).get("edit_mode_key") or "").strip()
    return k or "1234"

def _auth_ok(request: Request) -> bool:
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == _edit_key_expected()

async def get_config(request: Request):
    return JSONResponse(_read_cfg())

async def set_config(request: Request):
    # Protect writes
    if not _auth_ok(request):
        return JSONResponse({"error": "forbidden"}, status_code=403)

    body = {}
    try:
        body = await request.json()
    except Exception:
        body = {}

    keys = (body.get("keys") or {})
    cfg = _write_cfg(keys)
    return JSONResponse({"ok": True, "keys": cfg["keys"]})
PY

# 3) Ensure ops_git exists (do not overwrite if already present)
if [ ! -f backend/app/routes/ops_git.py ]; then
  cat > backend/app/routes/ops_git.py <<'PY'
import os, json, subprocess
from starlette.responses import JSONResponse
from starlette.requests import Request

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
UUI_STORE = os.path.abspath(os.path.join(ROOT_DIR, "station_meta", "bindings", "uui_config.json"))

def _read_uui_keys():
    try:
        with open(UUI_STORE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        return (cfg.get("keys") or {})
    except Exception:
        return {}

def _edit_key_expected():
    envk = (os.getenv("STATION_EDIT_KEY") or "").strip()
    if envk:
        return envk
    keys = _read_uui_keys()
    k = (keys.get("edit_mode_key") or "").strip()
    return k or "1234"

def _auth_ok(request: Request) -> bool:
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == _edit_key_expected()

def _run(cmd: list[str]) -> tuple[int, str]:
    p = subprocess.Popen(
        cmd,
        cwd=ROOT_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )
    out = []
    for line in p.stdout:
        out.append(line)
    p.wait()
    return p.returncode, "".join(out)

async def git_status(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"error": "forbidden"}, status_code=403)

    rc1, out1 = _run(["bash", "-lc", "git status --porcelain=v1 || true"])
    rc2, out2 = _run(["bash", "-lc", "git log --oneline -n 5 || true"])
    rc3, out3 = _run(["bash", "-lc", "git remote -v || true"])

    return JSONResponse({
        "ok": True,
        "porcelain": out1.strip(),
        "log": out2.strip(),
        "remote": out3.strip(),
        "rc": [rc1, rc2, rc3]
    })

async def git_push(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"error": "forbidden"}, status_code=403)

    body = {}
    try:
        body = await request.json()
    except Exception:
        body = {}

    root_id = int(body.get("root_id") or 0)
    msg = str(body.get("msg") or "UI push").strip()
    strict = str(body.get("strict") or "0").strip()

    env = os.environ.copy()
    env["STRICT_PUSH"] = "1" if strict in ("1", "true", "yes") else "0"

    script = os.path.join(ROOT_DIR, "scripts", "ops", "stage_commit_push.sh")
    if not os.path.exists(script):
        return JSONResponse({"error": "stage_commit_push.sh not found"}, status_code=500)

    p = subprocess.Popen(
        ["bash", script, str(root_id), msg],
        cwd=ROOT_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=env
    )
    out = []
    for line in p.stdout:
        out.append(line)
    p.wait()
    tail = "".join(out)[-2200:]

    return JSONResponse({"ok": p.returncode == 0, "rc": p.returncode, "out_tail": tail})
PY
fi

# 4) Ensure store file exists with defaults
if [ ! -f station_meta/bindings/uui_config.json ]; then
  cat > station_meta/bindings/uui_config.json <<'JSON'
{
  "keys": {
    "openai_api_key": "",
    "github_token": "",
    "tts_key": "",
    "webhooks_url": "",
    "ocr_key": "",
    "web_integration_key": "",
    "whatsapp_key": "",
    "email_smtp": "",
    "github_repo": "",
    "render_api_key": "",
    "edit_mode_key": "1234"
  }
}
JSON
fi

# 5) Patch backend/app/main.py to import and mount routes if missing
python - <<'PY'
import re
from pathlib import Path

p = Path("backend/app/main.py")
txt = p.read_text(encoding="utf-8")

# imports
if "from app.routes import uui_config" not in txt:
    txt = txt.replace(
        "from starlette.routing import Route",
        "from starlette.routing import Route\nfrom app.routes import uui_config"
    )
if "from app.routes import ops_git" not in txt:
    txt = txt.replace(
        "from starlette.routing import Route",
        "from starlette.routing import Route\nfrom app.routes import ops_git"
    )

# routes
def ensure_route(path, handler, methods):
    nonlocal_txt = None

if "/api/config/uui" not in txt:
    txt = re.sub(
        r"routes\s*=\s*\[",
        "routes = [\n"
        "    Route('/api/config/uui', uui_config.get_config, methods=['GET']),\n"
        "    Route('/api/config/uui', uui_config.set_config, methods=['POST']),",
        txt,
        count=1
    )

if "/api/ops/git/status" not in txt:
    txt = re.sub(
        r"routes\s*=\s*\[",
        "routes = [\n"
        "    Route('/api/ops/git/status', ops_git.git_status, methods=['GET']),\n"
        "    Route('/api/ops/git/push', ops_git.git_push, methods=['POST']),",
        txt,
        count=1
    )

p.write_text(txt, encoding="utf-8")
print("OK: backend/app/main.py patched (uui_config + ops_git)")
PY

echo "OK: Backend uui_config + ops_git ready."
