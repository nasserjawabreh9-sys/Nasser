#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
MAIN="$ROOT/backend/main.py"

test -f "$MAIN" || { echo "Missing: $MAIN"; exit 1; }

python - <<'PY'
import re
from pathlib import Path

p = Path.home() / "station_root" / "backend" / "main.py"
txt = p.read_text(encoding="utf-8", errors="ignore")

marker = "# === STATION_CHAT_BLOCK_V4 ==="
if marker in txt:
    print("V4 already present.")
else:
    block = r'''
# === STATION_CHAT_BLOCK_V4 ===
# Hard guarantee: registers /chat + core endpoints on whatever ASGI app is created.
import os, time, subprocess
from typing import Dict, Any

try:
    from starlette.responses import JSONResponse
    from starlette.routing import Route
except Exception:
    JSONResponse = None
    Route = None

_OPS_BUCKET: Dict[str, Dict[str, Any]] = {}

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

def _run(cmd, cwd=None, timeout=60):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

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
    payload = {"model": model, "input": user_input}
    r = requests.post(url, headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"}, json=payload, timeout=60)

    try:
        data = r.json()
    except Exception:
        return JSONResponse({"ok": False, "status": r.status_code, "text": r.text}, status_code=502)

    return JSONResponse({"ok": r.ok, "status": r.status_code, "data": data})

async def ops_git_status(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok":False,"error":"unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok":False,"error":"rate_limited"}, status_code=429)
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    rc, out, err = _run(["git","status","--porcelain=v1","-b"], cwd=root, timeout=60)
    return JSONResponse({"ok": rc==0, "rc": rc, "out": out, "err": err})

def __station_bootstrap(app_obj):
    if JSONResponse is None or Route is None:
        return
    routes = getattr(getattr(app_obj, "router", None), "routes", None)
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

# Best-effort: if app already exists now, bootstrap immediately.
try:
    if "app" in globals():
        __station_bootstrap(app)
except Exception:
    pass
'''
    txt = txt.rstrip() + "\n\n" + marker + "\n" + block + "\n"
    print("Appended V4 block.")

# Try to inject bootstrap call after app creation lines:
# patterns: app = Starlette(...), app=Starlette(...), app = FastAPI(...), etc.
if "__station_bootstrap(app)" not in txt:
    patterns = [
        r"(?m)^(app\s*=\s*Starlette\s*\(.*\)\s*)$",
        r"(?m)^(app\s*=\s*FastAPI\s*\(.*\)\s*)$",
        r"(?m)^(app\s*=\s*Starlette\s*\(.*)$",
        r"(?m)^(app\s*=\s*FastAPI\s*\(.*)$",
    ]
    injected = False
    for pat in patterns:
        m = re.search(pat, txt)
        if m:
            idx = m.end()
            insert = "\ntry:\n    __station_bootstrap(app)\nexcept Exception:\n    pass\n"
            txt = txt[:idx] + insert + txt[idx:]
            injected = True
            print("Injected __station_bootstrap(app) after app creation.")
            break
    if not injected:
        print("WARNING: Could not locate app creation line for injection. V4 still appended (may require manual 1-line call).")

p.write_text(txt, encoding="utf-8")
print("OK: main.py updated.")
PY

echo "OK: patched. Restart backend now."
