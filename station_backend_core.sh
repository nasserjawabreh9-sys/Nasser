#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
BACK="$ROOT/backend"

echo "===================================="
echo "   ⛽ STATION BACKEND – LOOP V3 CORE"
echo "===================================="

mkdir -p "$BACK"
mkdir -p "$BACK/app"
mkdir -p "$BACK/loop_engine"
mkdir -p "$BACK/utils"
mkdir -p "$ROOT/workspace"

##############################################
# 1) requirements.txt
##############################################
cat > "$BACK/requirements.txt" << 'EOF'
fastapi
uvicorn
pydantic
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
    LOOP V3:
    1) Save message.
    2) Return system reply placeholder.
    """
    save_message("user", msg)

    reply = f"تم استلام رسالتك: {msg}"
    save_message("station", reply)

    return reply
EOF

##############################################
# 3) main.py
##############################################
cat > "$BACK/app/main.py" << 'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
from loop_engine.engine import process_user_message

app = FastAPI(title="STATION Backend – LOOP V3")

class ChatInput(BaseModel):
    message: str

@app.get("/health")
def health():
    return {"status": "ok", "loop": "v3", "utf8": True}

@app.post("/api/chat")
def chat_api(payload: ChatInput):
    msg = payload.message
    reply = process_user_message(msg)
    return {"reply": reply}
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
# 5) إنشاء venv + تثبيت المتطلبات
##############################################
cd "$BACK"
rm -rf .venv
python -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "===================================="
echo "   ✅ BACKEND LOOP V3 INSTALLED"
echo "   جاهز للمرحلة التالية."
echo "===================================="
