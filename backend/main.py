from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route
from starlette.middleware.cors import CORSMiddleware
import os

async def health(request):
    return JSONResponse({
        "status": "ok",
        "runtime": "station",
        "env": os.environ.get("STATION_ENV", "termux"),
        "engine": "starlette-core"
    })

routes = [
    Route("/health", health),
]

app = Starlette(debug=True, routes=routes)

# === STATION_FORCE_ROUTES_V1 ===
try:
    # Force-register station ops routes (idempotent)
    from starlette.routing import Route
    existing = set(getattr(r, 'path', None) for r in getattr(app.router, 'routes', []))
    def _add(path, fn, methods):
        if path not in existing:
            app.router.routes.append(Route(path, fn, methods=methods))
            existing.add(path)
    _add('/info', _info, ['GET'])
    _add('/version', _version, ['GET'])
    _add('/ops/git/status', _ops_git_status, ['POST'])
    _add('/ops/git/push', _ops_git_push, ['POST'])
    _add('/ops/render/deploy', _ops_render_deploy, ['POST'])
except Exception:
    pass


# CORS for frontend (Vite on 4173)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# === STATION_OPS_BLOCK_V2 ===
# Adds /info and /version for Starlette apps without breaking existing wiring.
import os as _os
import datetime as _dt

try:
    from starlette.responses import JSONResponse as _JSONResponse
    from starlette.routing import Route as _Route
except Exception:
    _JSONResponse = None
    _Route = None

def _station_now_iso():
    try:
        return _dt.datetime.utcnow().replace(microsecond=0).isoformat() + "Z"
    except Exception:
        return None

def _station_version():
    try:
        # repo root = one level above this file
        root = _os.path.abspath(_os.path.join(_os.path.dirname(__file__), ".."))
        vp = _os.path.join(root, "VERSION")
        if _os.path.exists(vp):
            return open(vp, "r", encoding="utf-8").read().strip()
    except Exception:
        pass
    return "station-unknown"

async def _station_info(request):
    return _JSONResponse({
        "name": "station",
        "engine": "starlette-core",
        "env": _os.getenv("ENV", "local"),
        "runtime": _os.getenv("RUNTIME", "termux"),
        "version": _station_version(),
        "time": _station_now_iso(),
    })

async def _station_version_handler(request):
    return _JSONResponse({
        "version": _station_version(),
        "time": _station_now_iso(),
    })

def _station_register_routes(app_obj):
    if _JSONResponse is None or _Route is None:
        return False
    try:
        routes = getattr(app_obj, "routes", None)
        if routes is None:
            return False
        paths = set(getattr(r, "path", None) for r in routes)
        if "/info" not in paths:
            routes.append(_Route("/info", _station_info, methods=["GET"]))
        if "/version" not in paths:
            routes.append(_Route("/version", _station_version_handler, methods=["GET"]))
        return True
    except Exception:
        return False

try:
    if "app" in globals():
        _station_register_routes(app)
except Exception:
    pass

# === STATION_OPS_POST_INIT_V1 ===

# === STATION_OPS_POST_INIT_V1 ===
# Ensure ops routes are registered AFTER app is created.
try:
    if "app" in globals():
        try:
            _apply_cors(app)
        except Exception:
            pass

        try:
            # Starlette/FastAPI both support add_route (FastAPI via Starlette underneath)
            app.add_route("/ops/git/status", _ops_git_status, methods=["POST"])
            app.add_route("/ops/git/push", _ops_git_push, methods=["POST"])
            app.add_route("/ops/render/deploy", _ops_render_deploy, methods=["POST"])
        except Exception:
            # fallback: router.routes append
            try:
                from starlette.routing import Route
                routes = getattr(app.router, "routes", None)
                if routes is not None:
                    paths = set(getattr(r, "path", None) for r in routes)
                    if "/ops/git/status" not in paths:
                        routes.append(Route("/ops/git/status", _ops_git_status, methods=["POST"]))
                    if "/ops/git/push" not in paths:
                        routes.append(Route("/ops/git/push", _ops_git_push, methods=["POST"]))
                    if "/ops/render/deploy" not in paths:
                        routes.append(Route("/ops/render/deploy", _ops_render_deploy, methods=["POST"]))
            except Exception:
                pass
except Exception:
    pass

# === STATION_OPS_BLOCK_V3 ===

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

# === STATION_CHAT_BLOCK_V4 ===

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

# === STATION_AGENT_BRIDGE_V1 ===

# === STATION_AGENT_BRIDGE_V1 ===
import os, json
from typing import Any, Dict

try:
    from starlette.responses import JSONResponse
    from starlette.routing import Route
except Exception:
    JSONResponse = None
    Route = None

from agent_queue import submit_task, claim_next, set_result, get_task, list_recent

def _edit_key_ok(request) -> bool:
    want = os.getenv("STATION_EDIT_KEY", "1234")
    got = request.headers.get("x-edit-key", "")
    return bool(got) and got == want

def _runner_key_ok(request) -> bool:
    want = os.getenv("STATION_RUNNER_KEY", "runner-1234")
    got = request.headers.get("x-runner-key", "")
    return bool(got) and got == want

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

def _register_agent_routes(app_obj):
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

    add("/agent/tasks/submit", agent_submit, ["POST"])
    add("/agent/tasks/next", agent_next, ["GET"])
    add("/agent/tasks/result", agent_result, ["POST"])
    add("/agent/tasks/recent", agent_recent, ["GET"])
    add("/agent/tasks/{tid:int}", agent_task_get, ["GET"])

try:
    if "app" in globals():
        _register_agent_routes(app)
except Exception:
    pass

# === STATION_FORCE_CORE_V1 ===

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

# === STATION_ROUTE_REG_V1 ===

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

# === UUL_EXTRA_DIGITAL_FACTORY_V2 ===

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

# === GLOBAL_V1_ROUTES ===

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

