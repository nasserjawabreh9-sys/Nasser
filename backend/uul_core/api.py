from __future__ import annotations
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from .state import STATE
from .dynamo import run_factory
from .taskbus import submit, next_task, report, recent

def _edit_ok(req: Request) -> bool:
    # keep minimal: presence of header.
    # your existing system can harden it later.
    return bool(req.headers.get("x-edit-key",""))

async def uul_factory_run(req: Request):
    if not _edit_ok(req):
        return JSONResponse({"ok":False,"error":"missing x-edit-key"}, status_code=401)
    run_factory()
    return JSONResponse({"ok":True,"running":STATE.running})

async def uul_factory_status(req: Request):
    tail = int(req.query_params.get("tail","160"))
    rooms = {k: {"status":v.status,"updated_at":v.updated_at,"last_error":v.last_error} for k,v in STATE.rooms.items()}
    return JSONResponse({
        "ok":True,
        "running":STATE.running,
        "started_at":STATE.started_at,
        "rooms":rooms,
        "log_tail": STATE.logs[-max(10, min(4000, tail)):]
    })

async def uul_task_submit(req: Request):
    if not _edit_ok(req):
        return JSONResponse({"ok":False,"error":"missing x-edit-key"}, status_code=401)
    body = await req.json()
    task_type = body.get("task_type","shell")
    payload = body.get("payload",{})
    tid = submit(task_type, payload)
    return JSONResponse({"ok":True,"task_id":tid})

async def uul_task_next(req: Request):
    runner_id = req.query_params.get("runner_id","runner-local")
    t = next_task(runner_id)
    if not t:
        return JSONResponse({"ok":True,"task":None})
    return JSONResponse({"ok":True,"task":{
        "id":t.id,
        "task_type":t.task_type,
        "payload":t.payload
    }})

async def uul_task_report(req: Request):
    body = await req.json()
    task_id = int(body.get("task_id",0))
    ok = bool(body.get("ok",False))
    result = body.get("result")
    error = body.get("error")
    done = report(task_id, ok, result=result, error=error)
    return JSONResponse({"ok":done})

async def uul_task_recent(req: Request):
    limit = int(req.query_params.get("limit","10"))
    items = []
    for t in recent(limit):
        items.append({
            "id": t.id,
            "created_at": t.created_at,
            "status": t.status,
            "runner_id": t.runner_id,
            "task_type": t.task_type,
            "payload": t.payload,
            "result": t.result,
            "error": t.error
        })
    return JSONResponse({"ok":True,"items":items})

def routes():
    return [
        Route("/uul/factory/run", uul_factory_run, methods=["POST"]),
        Route("/uul/factory/status", uul_factory_status, methods=["GET"]),
        Route("/uul/tasks/submit", uul_task_submit, methods=["POST"]),
        Route("/uul/tasks/next", uul_task_next, methods=["GET"]),
        Route("/uul/tasks/report", uul_task_report, methods=["POST"]),
        Route("/uul/tasks/recent", uul_task_recent, methods=["GET"]),
    ]
