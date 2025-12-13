from __future__ import annotations
import time
from .state import STATE, RoomState
from . import rooms

ROOMS = {
    "core": rooms.core,
    "backend": rooms.backend,
    "frontend": rooms.frontend,
    "tests": rooms.tests,
    "git_pipeline": rooms.git_pipeline,
    "render_deploy": rooms.render_deploy,
}

ORDER = ["core","backend","frontend","tests","git_pipeline","render_deploy"]

def ensure_rooms():
    for n in ORDER:
        if n not in STATE.rooms:
            STATE.rooms[n] = RoomState(name=n)

def run_factory():
    ensure_rooms()
    if STATE.running:
        STATE.log("[dynamo] already running")
        return
    STATE.running = True
    STATE.started_at = int(time.time())
    STATE.log("[dynamo] START")
    try:
        for n in ORDER:
            rs = STATE.rooms[n]
            rs.status = "running"
            rs.updated_at = int(time.time())
            rs.last_error = ""
            STATE.log(f"[dynamo] room={n} status=running")
            try:
                ROOMS[n]()
                rs.status = "done"
                rs.updated_at = int(time.time())
                STATE.log(f"[dynamo] room={n} status=done")
            except Exception as e:
                rs.status = "error"
                rs.updated_at = int(time.time())
                rs.last_error = str(e)
                STATE.log(f"[dynamo] room={n} status=error err={e}")
                break
    finally:
        STATE.running = False
        STATE.log("[dynamo] STOP")
