#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [R9100] Building Senses + Hooks (Backend + Frontend) ..."

mkdir -p backend/app/routes station_meta/bindings frontend/src/api frontend/src/pages

# -------------------------
# 0) Ensure uui_config store exists (keys)
# -------------------------
if [ ! -f station_meta/bindings/uui_config.json ]; then
  cat > station_meta/bindings/uui_config.json <<'JSON'
{
  "keys": {
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
}
JSON
fi

# -------------------------
# 1) Backend deps (Termux-safe) + add requests + python-multipart
# -------------------------
if [ -f backend/requirements.txt ]; then
  grep -qi '^requests==' backend/requirements.txt || echo 'requests==2.31.0' >> backend/requirements.txt
  grep -qi '^python-multipart==' backend/requirements.txt || echo 'python-multipart==0.0.9' >> backend/requirements.txt
else
  cat > backend/requirements.txt <<'EOF'
starlette==0.36.3
uvicorn==0.23.2
anyio==3.7.1
requests==2.31.0
python-multipart==0.0.9
EOF
fi

# -------------------------
# 2) Backend route: senses_and_hooks.py
# -------------------------
cat > backend/app/routes/senses_and_hooks.py <<'PY'
import os
import json
import requests
from starlette.responses import JSONResponse
from starlette.requests import Request
from starlette.datastructures import UploadFile

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
CFG_FILE = os.path.join(ROOT_DIR, "station_meta", "bindings", "uui_config.json")

def load_cfg():
    try:
        with open(CFG_FILE, "r", encoding="utf-8") as f:
            return json.load(f).get("keys", {})
    except Exception:
        return {}

def require_edit(request: Request) -> bool:
    cfg = load_cfg()
    expected = (cfg.get("edit_mode_key") or "1234").strip()
    got = (request.headers.get("X-Edit-Key") or "").strip()
    return got != "" and got == expected

# --------- SENSES ----------
async def sense_text(request: Request):
    data = await request.json()
    return JSONResponse({"sense": "text", "input": data})

async def sense_audio(request: Request):
    form = await request.form()
    audio: UploadFile = form.get("audio")
    size = len(await audio.read()) if audio else 0
    return JSONResponse({"sense": "audio", "bytes": size})

async def sense_image(request: Request):
    form = await request.form()
    image: UploadFile = form.get("image")
    size = len(await image.read()) if image else 0
    return JSONResponse({"sense": "image", "bytes": size})

# --------- HOOKS ----------
async def hook_email(request: Request):
    if not require_edit(request):
        return JSONResponse({"error": "forbidden"}, status_code=403)
    payload = await request.json()
    # Stub: real SMTP later (keep interface stable)
    return JSONResponse({"hook": "email", "sent": True, "payload": payload})

async def hook_whatsapp(request: Request):
    if not require_edit(request):
        return JSONResponse({"error": "forbidden"}, status_code=403)
    payload = await request.json()
    # Stub: Meta/Twilio later
    return JSONResponse({"hook": "whatsapp", "sent": True, "payload": payload})

async def hook_web(request: Request):
    if not require_edit(request):
        return JSONResponse({"error": "forbidden"}, status_code=403)
    payload = await request.json()
    cfg = load_cfg()
    url = (cfg.get("webhooks_url") or "").strip()
    if url:
        try:
            requests.post(url, json=payload, timeout=5)
        except Exception as e:
            return JSONResponse({"hook": "web", "error": str(e)}, status_code=500)
    return JSONResponse({"hook": "web", "sent": True, "payload": payload})
PY

# Ensure packages init
touch backend/app/__init__.py backend/app/routes/__init__.py

# -------------------------
# 3) Patch backend/app/main.py to mount routes
# -------------------------
python - <<'PY'
from pathlib import Path
import re

p = Path("backend/app/main.py")
txt = p.read_text(encoding="utf-8")

# Ensure import
if "from app.routes import senses_and_hooks" not in txt:
    if "from starlette.routing import Route" in txt:
        txt = txt.replace(
            "from starlette.routing import Route",
            "from starlette.routing import Route\nfrom app.routes import senses_and_hooks"
        )
    else:
        raise SystemExit("main.py missing: from starlette.routing import Route")

# Ensure routes inserted
if "/api/sense/text" not in txt:
    txt = re.sub(
        r"routes\s*=\s*\[",
        "routes = [\n"
        "    Route('/api/sense/text', senses_and_hooks.sense_text, methods=['POST']),\n"
        "    Route('/api/sense/audio', senses_and_hooks.sense_audio, methods=['POST']),\n"
        "    Route('/api/sense/image', senses_and_hooks.sense_image, methods=['POST']),\n"
        "    Route('/api/hooks/email', senses_and_hooks.hook_email, methods=['POST']),\n"
        "    Route('/api/hooks/whatsapp', senses_and_hooks.hook_whatsapp, methods=['POST']),\n"
        "    Route('/api/hooks/web', senses_and_hooks.hook_web, methods=['POST']),",
        txt,
        count=1
    )

p.write_text(txt, encoding="utf-8")
print("OK: backend/app/main.py mounted senses+hooks")
PY

# -------------------------
# 4) Ensure backend venv deps installed
# -------------------------
if [ -d backend/.venv ]; then
  echo ">>> [R9100] Installing backend deps..."
  bash -lc "cd '$ROOT/backend' && source .venv/bin/activate && python -m pip install -r requirements.txt"
else
  echo ">>> [R9100] WARNING: backend/.venv not found. Create venv first (station build scripts)."
fi

# -------------------------
# 5) Frontend API client + demo page
# -------------------------
cat > frontend/src/api/senses.ts <<'TS'
export async function sendText(data: any) {
  return fetch("/api/sense/text", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(data),
  }).then((r) => r.json());
}

export async function sendAudio(file: File) {
  const f = new FormData();
  f.append("audio", file);
  return fetch("/api/sense/audio", { method: "POST", body: f }).then((r) => r.json());
}

export async function sendImage(file: File) {
  const f = new FormData();
  f.append("image", file);
  return fetch("/api/sense/image", { method: "POST", body: f }).then((r) => r.json());
}

export async function hook(path: "email" | "whatsapp" | "web", payload: any, editKey: string) {
  return fetch(`/api/hooks/${path}`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Edit-Key": editKey || "",
    },
    body: JSON.stringify(payload),
  }).then(async (r) => {
    const j = await r.json().catch(() => ({}));
    return { status: r.status, ok: r.ok, data: j };
  });
}
TS

cat > frontend/src/pages/Senses.tsx <<'TSX'
import { useState } from "react";
import { sendText, hook } from "../api/senses";

export default function Senses() {
  const [editKey, setEditKey] = useState("1234");
  const [out, setOut] = useState<any>(null);

  return (
    <div style={{ padding: 16, fontFamily: "system-ui" }}>
      <h2 style={{ marginBottom: 8 }}>Senses + Hooks (Station)</h2>

      <div style={{ display: "flex", gap: 8, marginBottom: 12 }}>
        <input
          value={editKey}
          onChange={(e) => setEditKey(e.target.value)}
          placeholder="Edit Key"
          style={{ padding: 8, width: 220 }}
        />
        <button
          onClick={async () => setOut(await sendText({ msg: "hello from UI" }))}
          style={{ padding: "8px 12px" }}
        >
          Test Sense: Text
        </button>
        <button
          onClick={async () => setOut(await hook("email", { subject: "Hi", body: "Test" }, editKey))}
          style={{ padding: "8px 12px" }}
        >
          Test Hook: Email
        </button>
        <button
          onClick={async () => setOut(await hook("whatsapp", { to: "+000", body: "Ping" }, editKey))}
          style={{ padding: "8px 12px" }}
        >
          Test Hook: WhatsApp
        </button>
        <button
          onClick={async () => setOut(await hook("web", { event: "ping", payload: { a: 1 } }, editKey))}
          style={{ padding: "8px 12px" }}
        >
          Test Hook: Web
        </button>
      </div>

      <pre style={{ background: "#111", color: "#eee", padding: 12, borderRadius: 8, overflow: "auto" }}>
        {JSON.stringify(out, null, 2)}
      </pre>

      <p style={{ marginTop: 12, opacity: 0.8 }}>
        ملاحظة: صفحة Demo فقط. دمجها بالواجهة الرسمية يتم بالمرحلة القادمة.
      </p>
    </div>
  );
}
TSX

# -------------------------
# 6) Quick local verification (no UI router edit)
# -------------------------
echo ">>> [R9100] Backend routes ready."
echo "Test backend now (after run):"
echo "  curl -X POST http://127.0.0.1:8000/api/sense/text -H 'Content-Type: application/json' -d '{\"msg\":\"hi\"}'"
echo "Hooks require header X-Edit-Key (default 1234 or from Settings):"
echo "  curl -X POST http://127.0.0.1:8000/api/hooks/email -H 'X-Edit-Key: 1234' -H 'Content-Type: application/json' -d '{\"subject\":\"x\"}'"

echo ">>> [R9100] DONE."
