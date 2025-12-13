import os
import json
import subprocess
from pathlib import Path
from starlette.responses import JSONResponse
from starlette.requests import Request
from .global_guards import require_edit_key, try_lock, unlock

ROOT = Path(os.environ.get("STATION_ROOT", str(Path.home() / "station_root")))

def _run(cmd, cwd=None):
    p = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, shell=False)
    return p.returncode, p.stdout.strip(), p.stderr.strip()

async def ops_git_status(request: Request):
    err = require_edit_key(request.headers)
    if err:
        return JSONResponse({"ok": False, "error": err}, status_code=401)

    if not try_lock("ops_git_status", ttl_sec=10):
        return JSONResponse({"ok": False, "error": "locked"}, status_code=423)

    try:
        code, out, e = _run(["git", "status", "--porcelain", "-b"], cwd=str(ROOT))
        return JSONResponse({"ok": code == 0, "code": code, "stdout": out, "stderr": e})
    finally:
        unlock("ops_git_status")

async def ops_git_push(request: Request):
    err = require_edit_key(request.headers)
    if err:
        return JSONResponse({"ok": False, "error": err}, status_code=401)

    if not try_lock("ops_git_push", ttl_sec=120):
        return JSONResponse({"ok": False, "error": "locked"}, status_code=423)

    try:
        body = await request.json()
        msg = (body.get("message") or "GLOBAL: update").strip()

        code1, out1, e1 = _run(["git", "add", "-A"], cwd=str(ROOT))
        code2, out2, e2 = _run(["git", "commit", "-m", msg], cwd=str(ROOT))
        # commit might fail if no changes
        code3, out3, e3 = _run(["git", "push", "-u", "origin", "main"], cwd=str(ROOT))

        return JSONResponse({
            "ok": code3 == 0,
            "steps": {
                "add": {"code": code1, "stdout": out1, "stderr": e1},
                "commit": {"code": code2, "stdout": out2, "stderr": e2},
                "push": {"code": code3, "stdout": out3, "stderr": e3}
            }
        })
    finally:
        unlock("ops_git_push")

async def ops_render_deploy(request: Request):
    err = require_edit_key(request.headers)
    if err:
        return JSONResponse({"ok": False, "error": err}, status_code=401)

    if not try_lock("ops_render_deploy", ttl_sec=300):
        return JSONResponse({"ok": False, "error": "locked"}, status_code=423)

    try:
        # Placeholder: in Render, deploy is typically triggered by Git push.
        # If you have Render Deploy Hook URL, store it in env: RENDER_DEPLOY_HOOK_URL
        hook = os.environ.get("RENDER_DEPLOY_HOOK_URL", "").strip()
        if not hook:
            return JSONResponse({"ok": False, "error": "missing_render_deploy_hook_url"}, status_code=400)

        # Use curl if available
        code, out, e = _run(["curl", "-sS", "-X", "POST", hook], cwd=str(ROOT))
        return JSONResponse({"ok": code == 0, "code": code, "stdout": out, "stderr": e})
    finally:
        unlock("ops_render_deploy")
