#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
BACK="$ROOT/backend"

echo "===================================="
echo "   ⛽ STATION BACKEND – LOOP V3 CORE (Starlette)"
echo "===================================="

mkdir -p "$BACK"
mkdir -p "$BACK/app"
mkdir -p "$BACK/loop_engine"
mkdir -p "$BACK/utils"
mkdir -p "$ROOT/workspace"

# تأكد من وجود __init__.py حتى تعمل الاستيرادات
touch "$BACK/app/__init__.py"
touch "$BACK/loop_engine/__init__.py"
touch "$BACK/utils/__init__.py"

##############################################
# 1) requirements.txt (بدون pydantic / fastapi)
##############################################
cat > "$BACK/requirements.txt" << 'EOF'
starlette==0.27.0
uvicorn==0.23.2
EOF

##############################################
# 2) loop_engine/engine.py
##############################################
cat > "$BACK/loop_engine/engine.py" << 'EOF'
import json
import os

WORKSPACE = os.path.expanduser("~/station_root/workspace")

def ensure_workspace():
    if not os.path.exists(WORKSPACE):
        os.makedirs(WORKSPACE, exist_ok=True)

def save_message(role: str, content: str):
    ensure_workspace()
    path = os.path.join(WORKSPACE, "loop_messages.json")

    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    else:
        data = []

    data.append({"role": role, "content": content})

    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def process_user_message(msg: str) -> str:
    """
    LOOP V3 (بدون LLM):
    1) نحفظ رسالة المستخدم.
    2) نرجّع رد بسيط.
    """
    save_message("user", msg)
    reply = f"تم استلام رسالتك: {msg}"
    save_message("station", reply)
    return reply
EOF

##############################################
# 3) app/main.py باستخدام Starlette فقط
##############################################
cat > "$BACK/app/main.py" << 'EOF'
from starlette.applications import Starlette
from starlette.responses import JSONResponse
from starlette.routing import Route
from starlette.requests import Request

from loop_engine.engine import process_user_message

async def health(request: Request):
    return JSONResponse({"status": "ok", "loop": "v3", "utf8": True})

async def chat_api(request: Request):
    data = await request.json()
    msg = data.get("message", "")
    reply = process_user_message(msg)
    return JSONResponse({"reply": reply})

routes = [
    Route("/health", health),
    Route("/api/chat", chat_api, methods=["POST"]),
]

app = Starlette(debug=False, routes=routes)
EOF

##############################################
# 4) سكربت تشغيل backend
##############################################
cat > "$BACK/run_backend.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
cd "$HOME/station_root/backend"
source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8810
EOF

chmod +x "$BACK/run_backend.sh"

##############################################
# 5) إنشاء venv جديد + تثبيت المتطلبات الخفيفة
##############################################
cd "$BACK"
rm -rf .venv
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "===================================="
echo "   ✅ BACKEND LOOP V3 (Starlette) READY"
echo "   جاهز للتشغيل على 8810."
echo "===================================="
