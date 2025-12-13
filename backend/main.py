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

