from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.settings_store import merged_keys, write_keys, expected_edit_key

def _auth_ok(request: Request) -> bool:
  got = (request.headers.get("X-Edit-Key") or "").strip()
  return got != "" and got == expected_edit_key()

async def get_settings(request: Request):
  return JSONResponse({"ok": True, "keys": merged_keys()})

async def set_settings(request: Request):
  if not _auth_ok(request):
    return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)
  body = {}
  try:
    body = await request.json()
  except Exception:
    body = {}
  keys = (body.get("keys") or {})
  merged = write_keys(keys)
  return JSONResponse({"ok": True, "keys": merged})

routes = [
  Route("/api/settings", get_settings, methods=["GET"]),
  Route("/api/settings", set_settings, methods=["POST"]),
]
