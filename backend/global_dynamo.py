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
