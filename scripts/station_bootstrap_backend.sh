#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[STATION] Backend bootstrap starting..."

# تحميل متغيرات البيئة
if [ -f "$HOME/station_env.sh" ]; then
  . "$HOME/station_env.sh"
  echo "[STATION] station_env.sh loaded."
else
  echo "[STATION] WARNING: station_env.sh not found. Continue anyway..."
fi

# إنشاء الشجرة الأساسية
mkdir -p "$HOME/station_root/backend/app" \
         "$HOME/station_root/frontend" \
         "$HOME/station_root/scripts" \
         "$HOME/station_root/config" \
         "$HOME/station_root/data"

cd "$HOME/station_root/backend"

# تهيئة venv
if [ ! -d ".venv" ]; then
  echo "[STATION] Creating Python venv..."
  python -m venv .venv
fi

. .venv/bin/activate

# requirements
cat > requirements.txt << 'REQ'
fastapi==0.95.2
uvicorn==0.23.2
pydantic==1.10.13
starlette==0.27.0
httpx==0.27.0
python-dotenv==1.0.1
REQ

echo "[STATION] Installing Python deps..."
pip install --upgrade pip
pip install -r requirements.txt

# ملفات الباك إند الأساسية
mkdir -p app/routes

cat > app/__init__.py << 'PY'
# STATION backend package
PY

cat > app/schemas.py << 'PY'
from pydantic import BaseModel

class ChatRequest(BaseModel):
    message: str

class ChatResponse(BaseModel):
    reply: str

class ConfigStatus(BaseModel):
    openai_configured: bool
    github_configured: bool
    backend_version: str
PY

cat > app/config.py << 'PY'
import os
from .schemas import ConfigStatus

def get_config_status() -> ConfigStatus:
    openai_key = os.getenv("STATION_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY")
    github_token = os.getenv("GITHUB_TOKEN")

    return ConfigStatus(
        openai_configured=bool(openai_key),
        github_configured=bool(github_token),
        backend_version="station-1.0",
    )

def get_openai_key() -> str:
    return os.getenv("STATION_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY") or ""
PY

cat > app/routes/config.py << 'PY'
from fastapi import APIRouter
from ..config import get_config_status
from ..schemas import ConfigStatus

router = APIRouter(prefix="/config", tags=["config"])

@router.get("", response_model=ConfigStatus)
async def read_config():
    return get_config_status()
PY

cat > app/routes/chat.py << 'PY'
from fastapi import APIRouter, HTTPException
from ..schemas import ChatRequest, ChatResponse
from ..config import get_openai_key
import httpx
import os

router = APIRouter(prefix="/chat", tags=["chat"])

OPENAI_API_URL = "https://api.openai.com/v1/chat/completions"
MODEL_NAME = os.getenv("STATION_MODEL_NAME", "gpt-4.1-mini")

@router.post("", response_model=ChatResponse)
async def chat(req: ChatRequest):
    api_key = get_openai_key()
    if not api_key:
        raise HTTPException(status_code=500, detail="OpenAI API key not configured on STATION.")

    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": MODEL_NAME,
        "messages": [
            {"role": "system", "content": "You are STATION assistant for Nasser."},
            {"role": "user", "content": req.message},
        ],
    }

    async with httpx.AsyncClient(timeout=40.0) as client:
        r = await client.post(OPENAI_API_URL, headers=headers, json=payload)
        if r.status_code != 200:
            raise HTTPException(status_code=500, detail=f"OpenAI error: {r.text}")

        data = r.json()
        reply = data["choices"][0]["message"]["content"]
        return ChatResponse(reply=reply)
PY

cat > app/main.py << 'PY'
from fastapi import FastAPI
from .routes import config as config_routes
from .routes import chat as chat_routes

app = FastAPI(title="STATION Backend", version="1.0.0")

@app.get("/health")
async def health():
    return {"status": "ok", "service": "station-backend"}

app.include_router(config_routes.router)
app.include_router(chat_routes.router)
PY

echo "[STATION] Backend bootstrap done."
echo "To run backend:"
echo "  cd \$HOME/station_root/backend"
echo "  . .venv/bin/activate"
echo "  uvicorn app.main:app --host 0.0.0.0 --port 8000"
