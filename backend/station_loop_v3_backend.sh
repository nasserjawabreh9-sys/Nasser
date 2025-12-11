#!/data/data/com.termux/files/usr/bin/bash
set -e

echo ">>> [STATION LOOP v3] Backend setup starting..."

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
WORK="$ROOT/workspace"

mkdir -p "$WORK"
mkdir -p "$BACK/app"
mkdir -p "$BACK/loop_actions"

echo ">>> [STATION LOOP v3] Writing loop_actions skeleton..."

cat > "$BACK/loop_actions/__init__.py" << 'PY'
from .analyze import handle_analyze
from .build import handle_build
from .push import handle_push
from .render import handle_render
from .agent import handle_agent
from .llm import handle_llm
PY

cat > "$BACK/loop_actions/analyze.py" << 'PY'
from typing import Dict, Any

def handle_analyze(command: Dict[str, Any]) -> Dict[str, Any]:
    """
    Placeholder للتحليل المستقبلي.
    سيُستخدم لاحقاً لتحليل الأوامر (تصنيف، فهم، إلخ).
    """
    return {
        "action": "analyze",
        "status": "stub",
        "note": "Analyze engine not implemented yet.",
        "command_id": command.get("id"),
    }
PY

cat > "$BACK/loop_actions/build.py" << 'PY'
from typing import Dict, Any

def handle_build(command: Dict[str, Any]) -> Dict[str, Any]:
    """
    Placeholder للبناء (توليد سكربتات/ملفات).
    """
    return {
        "action": "build",
        "status": "stub",
        "note": "Build engine not implemented yet.",
        "command_id": command.get("id"),
    }
PY

cat > "$BACK/loop_actions/push.py" << 'PY'
from typing import Dict, Any

def handle_push(command: Dict[str, Any]) -> Dict[str, Any]:
    """
    Placeholder للدفع إلى GitHub أو غيره.
    """
    return {
        "action": "push",
        "status": "stub",
        "note": "Push engine not implemented yet.",
        "command_id": command.get("id"),
    }
PY

cat > "$BACK/loop_actions/render.py" << 'PY'
from typing import Dict, Any

def handle_render(command: Dict[str, Any]) -> Dict[str, Any]:
    """
    Placeholder للنشر على Render أو أي بيئة.
    """
    return {
        "action": "render",
        "status": "stub",
        "note": "Render engine not implemented yet.",
        "command_id": command.get("id"),
    }
PY

cat > "$BACK/loop_actions/agent.py" << 'PY'
from typing import Dict, Any

def handle_agent(command: Dict[str, Any]) -> Dict[str, Any]:
    """
    Placeholder لطبقة الـ Agent (بصمتك / Nasser-lite).
    """
    return {
        "action": "agent",
        "status": "stub",
        "note": "Agent engine not implemented yet.",
        "command_id": command.get("id"),
    }
PY

cat > "$BACK/loop_actions/llm.py" << 'PY'
from typing import Dict, Any

def handle_llm(command: Dict[str, Any]) -> Dict[str, Any]:
    """
    Placeholder للتكامل مع LLM خارجي.
    """
    return {
        "action": "llm",
        "status": "stub",
        "note": "LLM engine not implemented yet.",
        "command_id": command.get("id"),
    }
PY

echo ">>> [STATION LOOP v3] Writing app/main.py ..."

cat > "$BACK/app/main.py" << 'PY'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from pathlib import Path
from datetime import datetime, timezone
import os
import json

try:
    from openai import OpenAI  # type: ignore
except ImportError:  # pragma: no cover
    OpenAI = None  # type: ignore


# -------- Paths & workspace --------
ROOT_PATH = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT_PATH / "workspace"
LOOP_LOG = WORKSPACE / "loop_log.jsonl"

WORKSPACE.mkdir(parents=True, exist_ok=True)


# -------- Models --------
class ChatRequest(BaseModel):
    message: str


class ChatResponse(BaseModel):
    reply: str


class LoopCommandIn(BaseModel):
    message: str
    source: str = "frontend"
    intent: str = "generic"
    tags: List[str] = Field(default_factory=list)


class LoopCommandOut(BaseModel):
    id: int
    message: str
    source: str
    intent: str
    tags: List[str]
    created_at: datetime


class LoopStats(BaseModel):
    total_commands: int
    by_intent: Dict[str, int]
    by_source: Dict[str, int]
    first_command_at: Optional[datetime]
    last_command_at: Optional[datetime]


# -------- OpenAI helper (سيُستخدم لاحقاً) --------
def get_openai_client():
    api_key = os.getenv("STATION_OPENAI_API_KEY") or os.getenv("OPENAI_API_KEY")
    if not api_key or OpenAI is None:
        return None
    return OpenAI(api_key=api_key)


# -------- Loop storage helpers (JSONL) --------
def _load_loop_records() -> List[Dict[str, Any]]:
    if not LOOP_LOG.exists():
        return []
    records: List[Dict[str, Any]] = []
    with LOOP_LOG.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
                records.append(obj)
            except json.JSONDecodeError:
                continue
    return records


def _append_loop_record(rec: Dict[str, Any]) -> None:
    with LOOP_LOG.open("a", encoding="utf-8") as f:
        f.write(json.dumps(rec, ensure_ascii=False) + "\\n")


def _record_to_out(rec: Dict[str, Any]) -> LoopCommandOut:
    return LoopCommandOut(
        id=rec["id"],
        message=rec["message"],
        source=rec.get("source", "frontend"),
        intent=rec.get("intent", "generic"),
        tags=rec.get("tags", []),
        created_at=datetime.fromisoformat(rec["created_at"]),
    )


# -------- Station app --------
app = FastAPI(
    title="Station Backend",
    version="0.3.0",
    description="Minimal bridge backend for Termux Station (health, echo, chat, loop v3).",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# -------- Basic endpoints --------
@app.get("/health")
def health():
    records = _load_loop_records()
    return {
        "status": "ok",
        "service": "station_backend",
        "port": 8810,
        "features": [
            "health",
            "echo",
            "chat",
            "loop_command",
            "loop_list",
            "loop_stats",
            "loop_route",
        ],
        "loop_count": len(records),
    }


@app.get("/")
def root():
    return {
        "message": "Station backend running",
        "hint": "Use /health, /api/echo, /api/chat, /api/loop/command, /api/loop/list, /api/loop/stats",
    }


@app.get("/api/echo")
def echo(msg: str = "hello"):
    return {"echo": msg}


# -------- Chat endpoint (جاهز للمستقبل، غير مطلوب الآن) --------
@app.post("/api/chat", response_model=ChatResponse)
def chat(body: ChatRequest):
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


# -------- Loop v3: command logging & stats --------
@app.post("/api/loop/command", response_model=LoopCommandOut)
def loop_command(body: LoopCommandIn):
    """
    يسجّل أمر واحد في loop_log.jsonl مع:
    - id
    - message
    - source
    - intent
    - tags
    - created_at (UTC ISO)
    """
    records = _load_loop_records()
    last_id = records[-1]["id"] if records else 0
    new_id = last_id + 1
    now_iso = datetime.now(timezone.utc).isoformat()

    rec: Dict[str, Any] = {
        "id": new_id,
        "message": body.message,
        "source": body.source,
        "intent": body.intent,
        "tags": body.tags,
        "created_at": now_iso,
    }

    _append_loop_record(rec)
    return _record_to_out(rec)


@app.get("/api/loop/list", response_model=List[LoopCommandOut])
def loop_list(limit: int = 50):
    """
    يرجّع آخر الأوامر (افتراضياً 50).
    """
    records = _load_loop_records()
    if limit > 0:
        records = records[-limit:]
    return [_record_to_out(r) for r in records]


@app.get("/api/loop/stats", response_model=LoopStats)
def loop_stats():
    """
    إحصائيات عن loop:
    - عدد الأوامر
    - توزيع حسب intent
    - توزيع حسب source
    - أول وآخر وقت.
    """
    records = _load_loop_records()
    total = len(records)
    by_intent: Dict[str, int] = {}
    by_source: Dict[str, int] = {}

    first_ts: Optional[datetime] = None
    last_ts: Optional[datetime] = None

    for r in records:
        intent = r.get("intent", "generic")
        source = r.get("source", "frontend")
        by_intent[intent] = by_intent.get(intent, 0) + 1
        by_source[source] = by_source.get(source, 0) + 1

        ts_str = r.get("created_at")
        if ts_str:
            try:
                ts = datetime.fromisoformat(ts_str)
                if first_ts is None or ts < first_ts:
                    first_ts = ts
                if last_ts is None or ts > last_ts:
                    last_ts = ts
            except ValueError:
                continue

    return LoopStats(
        total_commands=total,
        by_intent=by_intent,
        by_source=by_source,
        first_command_at=first_ts,
        last_command_at=last_ts,
    )


# -------- Loop router skeleton (Channel Router) --------
@app.post("/api/loop/route")
def loop_route(body: LoopCommandIn):
    """
    Router بسيط:
    - يحدّد القناة المقترحة (builder / github / render / termux / agent / llm / generic)
    - يسجّل الأمر أيضاً في log مع حقل route_channel (للاستخدام المستقبلي).
    """
    intent = body.intent.lower()
    if intent in ("build", "code", "script"):
        channel = "builder"
    elif intent in ("push", "github"):
        channel = "github"
    elif intent in ("render", "deploy"):
        channel = "render"
    elif intent in ("termux", "shell", "local"):
        channel = "termux"
    elif intent in ("agent", "nasser", "profile"):
        channel = "agent"
    elif intent in ("llm", "ai", "chat", "analysis"):
        channel = "llm"
    else:
        channel = "generic"

    records = _load_loop_records()
    last_id = records[-1]["id"] if records else 0
    new_id = last_id + 1
    now_iso = datetime.now(timezone.utc).isoformat()

    rec: Dict[str, Any] = {
        "id": new_id,
        "message": body.message,
        "source": body.source,
        "intent": body.intent,
        "tags": body.tags,
        "created_at": now_iso,
        "route_channel": channel,
    }
    _append_loop_record(rec)

    # مبدئياً نرجّع فقط معلومات القناة، بدون تنفيذ فعلي
    return {
        "id": new_id,
        "channel": channel,
        "saved": True,
    }
PY

echo ">>> [STATION LOOP v3] Backend updated successfully."
