import os, json
from starlette.responses import JSONResponse
from starlette.requests import Request

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
UUI_STORE = os.path.abspath(os.path.join(ROOT_DIR, "station_meta", "bindings", "uui_config.json"))

DEFAULT_KEYS = {
    "openai_api_key": "",
    "github_token": "",
    "tts_key": "",
    "webhooks_url": "",
    "ocr_key": "",
    "web_integration_key": "",
    "whatsapp_key": "",
    "email_smtp": "",
    "github_repo": "",
    "render_api_key": "",
    "edit_mode_key": "1234"
}

def _read_cfg():
    try:
        with open(UUI_STORE, "r", encoding="utf-8") as f:
            cfg = json.load(f)
        keys = (cfg.get("keys") or {})
        return {"keys": {**DEFAULT_KEYS, **keys}}
    except Exception:
        return {"keys": dict(DEFAULT_KEYS)}

def _write_cfg(keys: dict):
    os.makedirs(os.path.dirname(UUI_STORE), exist_ok=True)
    cfg = {"keys": {**DEFAULT_KEYS, **(keys or {})}}
    with open(UUI_STORE, "w", encoding="utf-8") as f:
        json.dump(cfg, f, ensure_ascii=False, indent=2)
    return cfg

def _edit_key_expected():
    envk = (os.getenv("STATION_EDIT_KEY") or "").strip()
    if envk:
        return envk
    cfg = _read_cfg()
    k = ((cfg.get("keys") or {}).get("edit_mode_key") or "").strip()
    return k or "1234"

def _auth_ok(request: Request) -> bool:
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == _edit_key_expected()

async def get_config(request: Request):
    return JSONResponse(_read_cfg())

async def set_config(request: Request):
    # Protect writes
    if not _auth_ok(request):
        return JSONResponse({"error": "forbidden"}, status_code=403)

    body = {}
    try:
        body = await request.json()
    except Exception:
        body = {}

    keys = (body.get("keys") or {})
    cfg = _write_cfg(keys)
    return JSONResponse({"ok": True, "keys": cfg["keys"]})
