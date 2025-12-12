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
