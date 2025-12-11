#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "===================================="
echo "   STATION – INTERNAL LOOP V1"
echo "   (backend only, no keys, no run)"
echo "===================================="

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
WORK="$ROOT/workspace"
ENGINE_DIR="$BACK/loop_engine"

echo
echo ">>> 1) تأكيد المجلدات…"
mkdir -p "$BACK"
mkdir -p "$ENGINE_DIR"
mkdir -p "$WORK"
mkdir -p "$WORK/out"

# ملف __init__ حتى تُعتبر حزمة بايثون
touch "$ENGINE_DIR/__init__.py"

##############################################
# 2) loop_engine/engine.py
##############################################
echo ">>> 2) كتابة loop_engine/engine.py …"

cat > "$ENGINE_DIR/engine.py" << 'EOF'
import json
import os
from datetime import datetime

ROOT = os.path.expanduser("~/station_root")
WORKSPACE = os.path.join(ROOT, "workspace")
LOG_PATH = os.path.join(WORKSPACE, "loop_messages.json")


def ensure_workspace() -> None:
    os.makedirs(WORKSPACE, exist_ok=True)


def load_messages():
    ensure_workspace()
    if os.path.exists(LOG_PATH):
        try:
            with open(LOG_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return []
    return []


def save_messages(msgs) -> None:
    ensure_workspace()
    with open(LOG_PATH, "w", encoding="utf-8") as f:
        json.dump(msgs, f, ensure_ascii=False, indent=2)


def save_message(role: str, content: str) -> None:
    msgs = load_messages()
    msgs.append(
        {
            "role": role,
            "content": content,
            "ts": datetime.utcnow().isoformat() + "Z",
        }
    )
    save_messages(msgs)


def process_user_message(msg: str) -> str:
    """
    LOOP داخلي بسيط:
    1) يحفظ رسالة المستخدم في workspace/loop_messages.json
    2) يرجّع رد نصي بسيط من STATION
    """
    text = msg or ""
    save_message("user", text)

    reply = f"STATION LOOP V3: تم استلام رسالتك ({len(text)} حروف)."
    save_message("station", reply)

    return reply
EOF

##############################################
# 3) loop_engine/planner.py
##############################################
echo ">>> 3) كتابة loop_engine/planner.py …"

cat > "$ENGINE_DIR/planner.py" << 'EOF'
import json
import os
from typing import Dict, Any

from .engine import WORKSPACE, ensure_workspace, load_messages

PLAN_PATH = os.path.join(WORKSPACE, "plan.json")


def build_plan_from_log() -> Dict[str, Any]:
    """
    يقرأ آخر رسالة user من السجل ويبني خطة أولية بسيطة.
    النتيجة تُكتب في workspace/plan.json.
    """
    ensure_workspace()
    msgs = load_messages()

    latest_user = None
    for m in reversed(msgs):
        if m.get("role") == "user":
            latest_user = m
            break

    if latest_user is None:
        plan = {
            "status": "no_user_message",
            "summary": "لا يوجد رسالة مستخدم في السجل بعد.",
        }
    else:
        text = latest_user.get("content") or ""
        plan = {
            "status": "ok",
            "summary": "خطة أولية مبسّطة مبنية على آخر رسالة.",
            "latest_user_message": text,
            # لاحقاً ممكن نطوّر هذه الحقول (نوع الملف، المسار، إلخ)
            "suggested_target_type": "text",
            "suggested_filename": "note_001.txt",
        }

    with open(PLAN_PATH, "w", encoding="utf-8") as f:
        json.dump(plan, f, ensure_ascii=False, indent=2)

    return plan
EOF

##############################################
# 4) loop_engine/actions.py
##############################################
echo ">>> 4) كتابة loop_engine/actions.py …"

cat > "$ENGINE_DIR/actions.py" << 'EOF'
import json
import os
from typing import Dict, Any, List

from .engine import WORKSPACE, ensure_workspace

OUT_DIR = os.path.join(WORKSPACE, "out")
PLAN_PATH = os.path.join(WORKSPACE, "plan.json")


def ensure_out_dir() -> None:
    ensure_workspace()
    os.makedirs(OUT_DIR, exist_ok=True)


def load_plan() -> Dict[str, Any]:
    ensure_workspace()
    if os.path.exists(PLAN_PATH):
        try:
            with open(PLAN_PATH, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {"status": "plan_corrupted"}
    return {"status": "no_plan"}


def generate_files_from_plan() -> Dict[str, Any]:
    """
    يقرأ plan.json ويولّد ملف نصي بسيط في workspace/out.
    الهدف: إكمال الـ LOOP (chat -> log -> plan -> file).
    """
    ensure_out_dir()
    plan = load_plan()

    filename = plan.get("suggested_filename") or "note_001.txt"
    path = os.path.join(OUT_DIR, filename)

    lines = [
        "STATION – LOOP GENERATED FILE",
        "",
        f"plan_status: {plan.get('status')}",
        "",
        "=== RAW PLAN JSON ===",
        json.dumps(plan, ensure_ascii=False, indent=2),
        "",
    ]

    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    return {
        "created_path": path,
        "file_name": filename,
        "plan_status": plan.get("status"),
    }


def list_generated_files() -> Dict[str, List[Dict[str, Any]]]:
    """
    يرجّع قائمة بالملفات الموجودة داخل workspace/out.
    """
    ensure_out_dir()
    files: List[Dict[str, Any]] = []

    for name in sorted(os.listdir(OUT_DIR)):
        full = os.path.join(OUT_DIR, name)
        if os.path.isfile(full):
            try:
                size = os.path.getsize(full)
            except OSError:
                size = 0
            files.append({"name": name, "size": size})

    return {"files": files}
EOF

##############################################
# 5) app/main.py – API داخلي للـ LOOP
##############################################
echo ">>> 5) كتابة app/main.py …"

mkdir -p "$BACK/app"

cat > "$BACK/app/main.py" << 'EOF'
from typing import Any, Dict

from fastapi import FastAPI
from loop_engine.engine import process_user_message
from loop_engine.planner import build_plan_from_log
from loop_engine.actions import generate_files_from_plan, list_generated_files

app = FastAPI(
    title="STATION Backend – INTERNAL LOOP V1",
    description=(
        "Backend بسيط يكمل الحلقة الداخلية:\n"
        "chat -> log -> plan -> file (workspace/out)\n"
        "لا مفاتيح ولا مزود LLM خارجي في هذه النسخة."
    ),
    version="0.1.0",
)


@app.get("/health")
def health() -> Dict[str, Any]:
    return {
        "status": "ok",
        "loop": "internal-v1",
        "utf8": True,
        "features": ["chat", "plan", "actions", "files"],
    }


@app.post("/api/chat")
def chat_api(payload: Dict[str, Any]) -> Dict[str, Any]:
    """
    يستقبل:
    { "message": "نص" }
    ويحفظه في loop_messages.json ويرجع رد بسيط من STATION.
    """
    msg = str(payload.get("message") or "")
    reply = process_user_message(msg)
    return {"reply": reply}


@app.post("/api/plan")
def plan_api() -> Dict[str, Any]:
    """
    يبني خطة من آخر رسالة user موجودة في السجل.
    النتيجة تُكتب في workspace/plan.json.
    """
    plan = build_plan_from_log()
    return {"plan": plan}


@app.post("/api/actions/run")
def actions_run_api() -> Dict[str, Any]:
    """
    يولّد ملف واحد على الأقل في workspace/out بناءً على plan.json.
    """
    result = generate_files_from_plan()
    return {"result": result}


@app.get("/api/actions/files")
def actions_files_api() -> Dict[str, Any]:
    """
    يرجّع قائمة الملفات الموجودة في workspace/out.
    """
    files = list_generated_files()
    return files
EOF

echo
echo "===================================="
echo "   ✅ INTERNAL LOOP V1 – BACKEND جاهز"
echo "   (لا venv جديد، لا pip، لا مفاتيح)"
echo "===================================="
