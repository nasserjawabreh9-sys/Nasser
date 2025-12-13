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
