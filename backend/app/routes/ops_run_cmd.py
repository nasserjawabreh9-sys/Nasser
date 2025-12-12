import subprocess
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.routing import Route
from app.settings_store import expected_edit_key

ALLOWED = {
  "pwd": ["pwd"],
  "ls":  ["ls", "-la"],
  "git_status": ["git", "status"],
  "git_log": ["git", "log", "--oneline", "-n", "20"]
}

def _auth_ok(request: Request) -> bool:
  got = (request.headers.get("X-Edit-Key") or "").strip()
  return got != "" and got == expected_edit_key()

async def run_cmd(request: Request):
  if not _auth_ok(request):
    return JSONResponse({"ok": False, "error": "forbidden"}, status_code=403)

  body = {}
  try:
    body = await request.json()
  except Exception:
    body = {}

  cmd_key = (body.get("cmd") or "").strip()
  if cmd_key not in ALLOWED:
    return JSONResponse({"ok": False, "error": "cmd_not_allowed", "allowed": list(ALLOWED.keys())}, status_code=400)

  try:
    p = subprocess.run(
      ALLOWED[cmd_key],
      capture_output=True,
      text=True,
      cwd=str((__import__("pathlib").Path(__file__).resolve().parents[3]))
    )
    return JSONResponse({
      "ok": True,
      "cmd": cmd_key,
      "returncode": p.returncode,
      "stdout": p.stdout[-4000:],
      "stderr": p.stderr[-4000:]
    })
  except Exception as e:
    return JSONResponse({"ok": False, "error": str(e)}, status_code=500)

routes = [
  Route("/api/ops/run_cmd", run_cmd, methods=["POST"]),
]
