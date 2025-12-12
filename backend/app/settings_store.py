import os, json, time
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[2]
SETTINGS_PATH = ROOT_DIR / "station_meta" / "settings" / "runtime_keys.json"

DEFAULTS = {
  "openai_api_key": "",
  "github_token": "",
  "render_api_key": "",
  "google_api_key": "",
  "tts_key": "",
  "ocr_key": "",
  "webhooks_url": "",
  "whatsapp_token": "",
  "email_smtp": "",
  "edit_mode_key": "1234"
}

ENV_MAP = {
  "openai_api_key": ["STATION_OPENAI_API_KEY", "OPENAI_API_KEY"],
  "github_token": ["GITHUB_TOKEN"],
  "render_api_key": ["RENDER_API_KEY"],
  "google_api_key": ["GOOGLE_API_KEY"],
  "tts_key": ["TTS_KEY"],
  "ocr_key": ["OCR_KEY"],
  "webhooks_url": ["WEBHOOKS_URL"],
  "whatsapp_token": ["WHATSAPP_TOKEN", "WHATSAPP_KEY"],
  "email_smtp": ["EMAIL_SMTP"],
  "edit_mode_key": ["STATION_EDIT_KEY", "EDIT_MODE_KEY"]
}

def _ensure():
  if SETTINGS_PATH.exists():
    return
  SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
  SETTINGS_PATH.write_text(json.dumps({"keys": DEFAULTS, "ts": time.time()}, indent=2), encoding="utf-8")

def _read_file() -> dict:
  _ensure()
  try:
    j = json.loads(SETTINGS_PATH.read_text(encoding="utf-8"))
    keys = (j.get("keys") or {})
    return keys if isinstance(keys, dict) else {}
  except Exception:
    return {}

def merged_keys() -> dict:
  _ensure()
  keys = dict(DEFAULTS)
  keys.update(_read_file())

  # env overrides
  for k, envs in ENV_MAP.items():
    for env in envs:
      v = (os.getenv(env) or "").strip()
      if v:
        keys[k] = v
        break

  keys["edit_mode_key"] = (keys.get("edit_mode_key") or "1234").strip() or "1234"
  return keys

def expected_edit_key() -> str:
  return merged_keys().get("edit_mode_key", "1234").strip() or "1234"

def write_keys(new_keys: dict) -> dict:
  _ensure()
  base = merged_keys()
  allow = set(DEFAULTS.keys())
  for k, v in (new_keys or {}).items():
    if k in allow:
      base[k] = "" if v is None else str(v)
  SETTINGS_PATH.write_text(json.dumps({"keys": base, "ts": time.time()}, indent=2), encoding="utf-8")
  return base
