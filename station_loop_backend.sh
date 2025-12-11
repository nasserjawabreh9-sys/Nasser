#!/data/data/com.termux/files/usr/bin/bash
set -e

echo ">>> [LOOP-BE] Station loop backend setup..."

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
WORK="$ROOT/workspace"

echo ">>> [LOOP-BE] ROOT  : $ROOT"
echo ">>> [LOOP-BE] BACK  : $BACK"
echo ">>> [LOOP-BE] WORK  : $WORK"

mkdir -p "$WORK"

# نخلي STATION_ROOT متاحة للباك اند (اختياري لكن مفيد)
export STATION_ROOT="$ROOT"

cd "$BACK"

echo ">>> [LOOP-BE] Writing app/main.py مع health + echo + chat + loop ..."

cat > app/main.py << 'PY'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from pathlib import Path
import os
import json
from datetime import datetime

try:
    from openai import OpenAI
except ImportError:
    OpenAI = None  # سيتم التعامل معها لاحقاً إذا لم تكن مثبتة


app = FastAPI(
    title="Station Backend",
    version="0.3.0",
    description="Station backend for Termux: health, echo, chat, loop logging.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str


class LoopCommand(BaseModel):
    command: str
    source: Optional[str] = "station_ui"


class LoopResult(BaseModel):
    status: str
    command: str
    stored_in: str


def get_openai_client() -> Optional["OpenAI"]:
    """
    نحاول أخذ المفتاح من:
    1) STATION_OPENAI_API_KEY
    2) OPENAI_API_KEY
    بالترتيب.
    (حتى لو مش هانستخدمها الآن، نتركها جاهزة.)
    """
    api_key = os.getenv("STATION_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY")
    if not api_key or OpenAI is None:
        return None
    return OpenAI(api_key=api_key)


def get_workspace_dir() -> Path:
    """
    يحدد مجلد workspace الخاص بالمحطة ويضمن وجوده.
    """
    root_env = os.getenv("STATION_ROOT")
    if root_env:
        root = Path(root_env)
    else:
        # backend/app/main.py → backend/app → backend → station_root
        root = Path(__file__).resolve().parents[2]
    work = root / "workspace"
    work.mkdir(parents=True, exist_ok=True)
    return work


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "station_backend",
        "port": 8810,
        "features": ["health", "echo", "chat", "loop"],
    }


@app.get("/")
def root():
    return {
        "message": "Station backend running",
        "hint": "Use /health, /api/echo, /api/chat, /api/loop/command",
    }


@app.get("/api/echo")
def echo(msg: str = "hello"):
    return {"echo": msg}


@app.post("/api/chat", response_model=ChatResponse)
def chat(body: ChatRequest):
    """
    نقطة بسيطة للذكاء الاصطناعي:
    - إذا لم يوجد مفتاح → نرمي خطأ 400 برسالة واضحة.
    - إذا حدث خطأ من مزود الـ API → نرمي 500 برسالة.
    (التشغيل الفعلي نأجّله لمرحلة لاحقة مع حل مشكلة openai على تيرمكس.)
    """
    client = get_openai_client()
    if client is None:
        raise HTTPException(
            status_code=400,
            detail=(
                "OpenAI API key not configured or 'openai' package not installed. "
                "Set STATION_OPENAI_API_KEY or OPENAI_API_KEY and install openai."
            ),
        )

    try:
        completion = client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "أنت مساعد صغير داخل محطة ناصر (STATION) على تيرمكس. "
                        "جاوب باختصار ووضوح وبأسلوب عملي."
                    ),
                },
                {
                    "role": "user",
                    "content": body.message,
                },
            ],
        )
        reply_text = completion.choices[0].message.content or ""
        return ChatResponse(reply=reply_text.strip())
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Chat backend error: {type(e).__name__}: {e}",
        )


@app.post("/api/loop/command", response_model=LoopResult)
def loop_command(body: LoopCommand):
    """
    هذه نقطة ال LOOP الأساسية:
    - تستقبل أمر نصّي من الواجهة (أو من أي عميل).
    - تخزّنه في ملف JSONL داخل workspace.
    - ترجع حالة بسيطة توضح أن الأمر تم تسجيله.

    لاحقًا نضيف:
    - تنفيذ فعلي على تيرمكس / GitHub / Render.
    - ربط مع LLM خارجي لتنفيذ أو تحليل الأوامر.
    """
    work = get_workspace_dir()
    log_path = work / "loop_log.jsonl"

    entry = {
        "ts": datetime.utcnow().isoformat() + "Z",
        "command": body.command,
        "source": body.source,
        "status": "queued",
    }

    with log_path.open("a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    return LoopResult(
        status="queued",
        command=body.command,
        stored_in=str(log_path),
    )
PY

echo ">>> [LOOP-BE] main.py updated with loop endpoint."
echo ">>> [LOOP-BE] Done."
