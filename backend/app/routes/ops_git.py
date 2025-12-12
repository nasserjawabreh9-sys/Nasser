import os, json, subprocess
from starlette.responses import JSONResponse
from starlette.requests import Request

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
UUI_STORE = os.path.abspath(os.path.join(ROOT_DIR, "station_meta", "bindings", "uui_config.json"))

def _read_uui_keys():
    try:
        with open(UUI_STORE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        return (cfg.get("keys") or {})
    except Exception:
        return {}

def _edit_key_expected():
    envk = (os.getenv("STATION_EDIT_KEY") or "").strip()
    if envk:
        return envk
    keys = _read_uui_keys()
    k = (keys.get("edit_mode_key") or "").strip()
    if k:
        return k
    return "1234"

def _auth_ok(request: Request) -> bool:
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == _edit_key_expected()

def _run(cmd: list[str]) -> tuple[int, str]:
    p = subprocess.Popen(
        cmd,
        cwd=ROOT_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )
    out = []
    for line in p.stdout:
        out.append(line)
    p.wait()
    return p.returncode, "".join(out)

async def git_status(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"error": "forbidden"}, status_code=403)

    rc1, out1 = _run(["bash", "-lc", "git status --porcelain=v1 || true"])
    rc2, out2 = _run(["bash", "-lc", "git log --oneline -n 5 || true"])
    rc3, out3 = _run(["bash", "-lc", "git remote -v || true"])

    return JSONResponse({
        "ok": True,
        "porcelain": out1.strip(),
        "log": out2.strip(),
        "remote": out3.strip(),
        "rc": [rc1, rc2, rc3]
    })

async def git_push(request: Request):
    if not _auth_ok(request):
        return JSONResponse({"error": "forbidden"}, status_code=403)

    body = {}
    try:
        body = await request.json()
    except Exception:
        body = {}

    root_id = int(body.get("root_id") or 0)
    msg = str(body.get("msg") or "UI push").strip()
    strict = str(body.get("strict") or "0").strip()

    env = os.environ.copy()
    env["STRICT_PUSH"] = "1" if strict in ("1", "true", "yes") else "0"

    script = os.path.join(ROOT_DIR, "scripts", "ops", "stage_commit_push.sh")
    if not os.path.exists(script):
        return JSONResponse({"error": "stage_commit_push.sh not found"}, status_code=500)

    p = subprocess.Popen(
        ["bash", script, str(root_id), msg],
        cwd=ROOT_DIR,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=env
    )
    out = []
    for line in p.stdout:
        out.append(line)
    p.wait()
    tail = "".join(out)[-2200:]

    return JSONResponse({
        "ok": p.returncode == 0,
        "rc": p.returncode,
        "out_tail": tail
    })
