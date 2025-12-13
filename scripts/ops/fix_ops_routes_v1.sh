#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

BE="$HOME/station_root/backend"
MAIN="$BE/main.py"

test -f "$MAIN" || { echo "Missing: $MAIN"; exit 1; }

python - <<'PY'
from pathlib import Path
p = Path.home() / "station_root" / "backend" / "main.py"
txt = p.read_text(encoding="utf-8", errors="ignore")

marker = "# === STATION_OPS_BLOCK_V3 ==="
if marker in txt:
    print("Ops V3 already present. Skipping.")
    raise SystemExit(0)

add = r'''
# === STATION_OPS_BLOCK_V3 ===
# Guaranteed ops route registration for Starlette
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

def _run(cmd, cwd=None, timeout=30):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

async def _info(request):
    return JSONResponse({
        "name": "station",
        "engine": os.getenv("ENGINE", "starlette-core"),
        "env": os.getenv("ENV", "local"),
        "runtime": os.getenv("RUNTIME", "termux"),
        "version": _read_version(),
        "time": _now_iso(),
    })

async def _version(request):
    return JSONResponse({"version": _read_version(), "time": _now_iso()})

async def _ops_git_status(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok": False, "error": "rate_limited"}, status_code=429)
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    rc, out, err = _run(["git", "status", "--porcelain=v1", "-b"], cwd=root, timeout=60)
    return JSONResponse({"ok": rc == 0, "rc": rc, "out": out, "err": err})

async def _ops_git_push(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok": False, "error": "rate_limited"}, status_code=429)
    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    _run(["git", "add", "-A"], cwd=root, timeout=60)
    rc1, out1, err1 = _run(["git", "commit", "-m", "station: ops commit"], cwd=root, timeout=60)
    rc2, out2, err2 = _run(["git", "push"], cwd=root, timeout=120)
    return JSONResponse({
        "ok": (rc2 == 0),
        "commit": {"rc": rc1, "out": out1, "err": err1},
        "push": {"rc": rc2, "out": out2, "err": err2},
    })

async def _ops_render_deploy(request):
    if not _edit_key_ok(request):
        return JSONResponse({"ok": False, "error": "unauthorized"}, status_code=401)
    ip = request.client.host if request.client else "unknown"
    if not _ops_allow(ip):
        return JSONResponse({"ok": False, "error": "rate_limited"}, status_code=429)

    try:
        body = await request.json()
    except Exception:
        body = {}

    api_key = (body.get("render_api_key") or os.getenv("RENDER_API_KEY") or "").strip()
    service_id = (body.get("render_service_id") or os.getenv("RENDER_SERVICE_ID") or "").strip()
    if not api_key or not service_id:
        return JSONResponse({"ok": False, "error": "missing_render_api_key_or_service_id"}, status_code=400)

    import requests
    url = f"https://api.render.com/v1/services/{service_id}/deploys"
    r = requests.post(url, headers={"Authorization": f"Bearer {api_key}"}, timeout=30)
    j = None
    try:
        j = r.json()
    except Exception:
        j = {"text": r.text}
    return JSONResponse({"ok": r.ok, "status": r.status_code, "json": j})

def _register_ops_routes(app_obj):
    if JSONResponse is None or Route is None:
        return
    routes = getattr(app_obj.router, "routes", None)
    if routes is None:
        return
    existing = set(getattr(r, "path", None) for r in routes)
    def add(path, fn, methods):
        if path not in existing:
            routes.append(Route(path, fn, methods=methods))
            existing.add(path)

    add("/info", _info, ["GET"])
    add("/version", _version, ["GET"])
    add("/ops/git/status", _ops_git_status, ["POST"])
    add("/ops/git/push", _ops_git_push, ["POST"])
    add("/ops/render/deploy", _ops_render_deploy, ["POST"])

try:
    if "app" in globals():
        _register_ops_routes(app)
except Exception:
    pass
'''

p.write_text(txt.rstrip() + "\n\n" + marker + "\n" + add + "\n", encoding="utf-8")
print("OK: Added STATION_OPS_BLOCK_V3")
PY

echo "OK: backend patched. Restart backend to apply."
