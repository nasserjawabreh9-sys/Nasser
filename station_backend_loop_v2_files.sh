#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "===================================="
echo "  🧠 STATION BACKEND – LOOP V2 FILES"
echo "  (بدون pip، بدون تشغيل، ملفات فقط)"
echo "===================================="

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
APP="$BACK/app"
LOOP="$BACK/loop_engine"
UTILS="$BACK/utils"
WORK="$ROOT/workspace"

mkdir -p "$BACK" "$APP" "$LOOP" "$UTILS" "$WORK"

##############################################
# 0) requirements.txt (نسخة آمنة لاحقًا)
##############################################
echo ">>> كتابة requirements.txt (جاهز للمستقبل)…"
cat > "$BACK/requirements.txt" << 'EOF'
fastapi==0.103.2
uvicorn==0.23.2
pydantic==1.10.12
EOF

##############################################
# 1) loop_engine/engine.py  (تخزين الرسائل)
##############################################
echo ">>> loop_engine/engine.py …"
cat > "$LOOP/engine.py" << 'EOF'
import json
import os
from typing import List, Dict, Any

ROOT = os.path.expanduser("~/station_root")
WORKSPACE = os.path.join(ROOT, "workspace")
LOG_PATH = os.path.join(WORKSPACE, "loop_messages.json")


def ensure_workspace() -> None:
    os.makedirs(WORKSPACE, exist_ok=True)


def load_messages() -> List[Dict[str, Any]]:
    ensure_workspace()
    if os.path.exists(LOG_PATH):
        with open(LOG_PATH, "r", encoding="utf-8") as f:
            try:
                return json.load(f)
            except Exception:
                return []
    return []


def save_messages(messages: List[Dict[str, Any]]) -> None:
    ensure_workspace()
    with open(LOG_PATH, "w", encoding="utf-8") as f:
        json.dump(messages, f, ensure_ascii=False, indent=2)


def append_message(role: str, content: str) -> None:
    msgs = load_messages()
    msgs.append({"role": role, "content": content})
    save_messages(msgs)


def process_user_message(msg: str) -> str:
    """
    LOOP: المرحلة الأولى
    1) نحفظ رسالة المستخدم في loop_messages.json
    2) نرجّع رد بسيط من STATION (مكان للـ LLM لاحقًا)
    """
    append_message("user", msg)
    reply = f"STATION LOOP استلمت: {msg}"
    append_message("station", reply)
    return reply
EOF

##############################################
# 2) loop_engine/plan_builder.py
##############################################
echo ">>> loop_engine/plan_builder.py …"
cat > "$LOOP/plan_builder.py" << 'EOF'
import json
import os
from typing import Any, Dict, List

from .engine import WORKSPACE, load_messages

PLAN_PATH = os.path.join(WORKSPACE, "plan.json")


def build_plan_from_messages() -> Dict[str, Any]:
    """
    خطة بسيطة من الرسائل:
    - نعتبر كل رسالة user = خطوة.
    - نحفظ plan.json داخل workspace.
    """
    msgs = load_messages()
    user_msgs: List[str] = [
        m["content"] for m in msgs if m.get("role") == "user"
    ]

    steps = []
    for idx, txt in enumerate(user_msgs, start=1):
        steps.append(
            {
                "id": idx,
                "title": f"خطوة {idx}",
                "description": txt,
                "status": "pending",
            }
        )

    plan: Dict[str, Any] = {
        "summary": {
            "total_messages": len(msgs),
            "user_steps": len(steps),
        },
        "steps": steps,
    }

    os.makedirs(WORKSPACE, exist_ok=True)
    with open(PLAN_PATH, "w", encoding="utf-8") as f:
        json.dump(plan, f, ensure_ascii=False, indent=2)

    return plan
EOF

##############################################
# 3) loop_engine/actions.py
##############################################
echo ">>> loop_engine/actions.py …"
cat > "$LOOP/actions.py" << 'EOF'
import json
import os
from datetime import datetime
from typing import Any, Dict, List

from .engine import WORKSPACE
from .plan_builder import PLAN_PATH, build_plan_from_messages


OUT_DIR = os.path.join(WORKSPACE, "out")


def ensure_out_dir() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)


def load_plan() -> Dict[str, Any]:
    if not os.path.exists(PLAN_PATH):
        # إذا لا يوجد plan، نبنيه من الرسائل أولاً
        return build_plan_from_messages()
    with open(PLAN_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def run_actions_from_plan() -> Dict[str, Any]:
    """
    تنفيذ بسيط:
    - نقرأ plan.json
    - ننشئ ملف في workspace/out يحتوي ملخّص الخطة
    """
    ensure_out_dir()
    plan = load_plan()
    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_name = f"station_plan_snapshot_{ts}.txt"
    file_path = os.path.join(OUT_DIR, file_name)

    lines: List[str] = []
    lines.append("STATION – PLAN SNAPSHOT")
    lines.append(f"Generated at: {ts}")
    lines.append("")
    lines.append("--- Summary ---")
    for k, v in plan.get("summary", {}).items():
        lines.append(f"{k}: {v}")

    lines.append("")
    lines.append("--- Steps ---")
    for step in plan.get("steps", []):
        lines.append(f"- [{step.get('status')}] ({step.get('id')}) {step.get('description')}")

    with open(file_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    return {
        "created_path": file_path,
        "file_name": file_name,
        "plan_status": "snapshot_created",
    }


def list_out_files() -> Dict[str, Any]:
    ensure_out_dir()
    files_info: List[Dict[str, Any]] = []
    for name in sorted(os.listdir(OUT_DIR)):
        full = os.path.join(OUT_DIR, name)
        if os.path.isfile(full):
            size = os.path.getsize(full)
            files_info.append({"name": name, "size": size})
    return {"files": files_info}
EOF

##############################################
# 4) app/main.py – API كاملة للـ LOOP
##############################################
echo ">>> app/main.py …"
cat > "$APP/main.py" << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel

from loop_engine.engine import process_user_message
from loop_engine.plan_builder import build_plan_from_messages
from loop_engine.actions import run_actions_from_plan, list_out_files


app = FastAPI(
    title="STATION Backend – LOOP V2",
    description="Loop داخلي: chat → log → plan → out-files",
    version="0.2.0",
)


class ChatInput(BaseModel):
    message: str


@app.get("/health")
def health():
    return {"status": "ok", "loop": "v2", "utf8": True}


@app.post("/api/chat")
def chat_api(payload: ChatInput):
    msg = payload.message
    reply = process_user_message(msg)
    return {"reply": reply}


@app.post("/api/plan")
def api_plan():
    plan = build_plan_from_messages()
    return {"plan": plan}


@app.post("/api/actions/run")
def api_actions_run():
    result = run_actions_from_plan()
    return {"result": result}


@app.get("/api/actions/files")
def api_actions_files():
    return list_out_files()
EOF

##############################################
# 5) تحديث run_backend.sh (بدون لمس venv)
##############################################
echo ">>> تحديث run_backend.sh …"
cat > "$BACK/run_backend.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/station_root/backend"

# لو عندك venv جاهز في المستقبل:
if [ -d ".venv" ]; then
  source .venv/bin/activate
fi

uvicorn app.main:app --host 0.0.0.0 --port 8810
EOF

chmod +x "$BACK/run_backend.sh"

echo
echo "===================================="
echo "  ✅ BACKEND LOOP V2 FILES جاهز"
echo "  (ملفات فقط – لا pip ولا تشغيل)"
echo "===================================="
