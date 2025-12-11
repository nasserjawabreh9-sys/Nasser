#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "===================================="
echo "   🧠 STATION BACKEND – LOOP V4"
echo "===================================="

ROOT="$HOME/station_root"
BACK="$ROOT/backend"

mkdir -p "$BACK"
mkdir -p "$BACK/app"
mkdir -p "$BACK/loop_engine"
mkdir -p "$BACK/utils"
mkdir -p "$ROOT/workspace"

##############################################
# 1) loop_engine/engine.py
##############################################
cat > "$BACK/loop_engine/engine.py" << 'EOF'
import json
import os
from typing import List, Dict, Any

ROOT = os.path.expanduser("~/station_root")
WORKSPACE = os.path.join(ROOT, "workspace")
MESSAGES_PATH = os.path.join(WORKSPACE, "loop_messages.json")
TASKS_PATH = os.path.join(WORKSPACE, "loop_tasks.json")


def _ensure_workspace() -> None:
    os.makedirs(WORKSPACE, exist_ok=True)


def _read_json(path: str, default):
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            try:
                return json.load(f)
            except Exception:
                return default
    return default


def _write_json(path: str, data) -> None:
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def save_message(role: str, content: str) -> None:
    """
    يحفظ أي رسالة في ملف loop_messages.json
    """
    _ensure_workspace()
    data: List[Dict[str, Any]] = _read_json(MESSAGES_PATH, [])
    data.append({"role": role, "content": content})
    _write_json(MESSAGES_PATH, data)


def process_user_message(msg: str) -> str:
    """
    LOOP بسيط:
    1) يحفظ رسالة المستخدم.
    2) يولّد رد بسيط (placeholder).
    3) يحفظ رد STATION.
    """
    save_message("user", msg)
    reply = f"تم استلام رسالتك في STATION: {msg}"
    save_message("station", reply)
    return reply


def list_tasks():
    """
    يرجع جميع المهام في loop_tasks.json
    """
    _ensure_workspace()
    tasks = _read_json(TASKS_PATH, [])
    return tasks


def create_task(kind: str, payload: dict):
    """
    ينشئ مهمة جديدة (هيكل فقط، بدون تنفيذ حقيقي).
    """
    _ensure_workspace()
    tasks = _read_json(TASKS_PATH, [])
    next_id = 1
    if tasks:
        try:
            next_id = max(t.get("id", 0) for t in tasks) + 1
        except Exception:
            next_id = len(tasks) + 1

    task = {
        "id": next_id,
        "kind": kind,
        "payload": payload,
        "status": "pending",  # later: running / done / failed
    }
    tasks.append(task)
    _write_json(TASKS_PATH, tasks)
    return task
EOF

##############################################
# 2) app/main.py
##############################################
cat > "$BACK/app/main.py" << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Dict, Any
from loop_engine.engine import process_user_message, create_task, list_tasks

app = FastAPI(
    title="STATION Backend – LOOP V4",
    version="0.4.0",
    description="هيكل اللوب بين الواجهة وملفات workspace بدون LLM خارجي."
)


class ChatInput(BaseModel):
    message: str


class ChatOutput(BaseModel):
    reply: str


class TaskIn(BaseModel):
    kind: str
    payload: Dict[str, Any]


class TaskOut(BaseModel):
    id: int
    kind: str
    payload: Dict[str, Any]
    status: str


@app.get("/health")
def health():
    return {
        "status": "ok",
        "loop": "v4",
        "utf8": True,
        "features": ["health", "echo", "chat", "loop-tasks"],
    }


@app.get("/api/echo")
def echo(msg: str = "hello"):
    return {"echo": msg}


@app.post("/api/chat", response_model=ChatOutput)
def chat_api(payload: ChatInput):
    reply = process_user_message(payload.message)
    return ChatOutput(reply=reply)


@app.get("/api/loop/tasks", response_model=List[TaskOut])
def get_tasks():
    raw_tasks = list_tasks()
    normalized: List[TaskOut] = []
    for t in raw_tasks:
        normalized.append(
            TaskOut(
                id=int(t.get("id", 0) or 0),
                kind=str(t.get("kind", "")),
                payload=dict(t.get("payload", {}) or {}),
                status=str(t.get("status", "pending")),
            )
        )
    return normalized


@app.post("/api/loop/submit", response_model=TaskOut)
def submit_task(task_in: TaskIn):
    task = create_task(task_in.kind, task_in.payload)
    return TaskOut(
        id=int(task.get("id", 0) or 0),
        kind=str(task.get("kind", "")),
        payload=dict(task.get("payload", {}) or {}),
        status=str(task.get("status", "pending")),
    )
EOF

##############################################
# 3) التأكيد على run_backend.sh
##############################################
cat > "$BACK/run_backend.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/station_root/backend"
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8810
EOF

chmod +x "$BACK/run_backend.sh"

echo
echo "===================================="
echo "  ✅ BACKEND LOOP V4 WIRED"
echo "  - /health, /api/echo, /api/chat"
echo "  - /api/loop/tasks, /api/loop/submit"
echo "  (لا تشغيل، فقط بناء الكود)"
echo "===================================="
