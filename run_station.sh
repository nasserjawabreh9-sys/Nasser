#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
FRONT="$ROOT/frontend"

echo ">>> [STATION] ROOT      : $ROOT"
echo ">>> [STATION] Backend   : http://127.0.0.1:8810"
echo ">>> [STATION] Frontend  : http://127.0.0.1:5173"

# 1) تحميل المتغيّرات
if [ -f "$ROOT/station_env.sh" ]; then
    echo ">>> [STATION] Loading env ..."
    source "$ROOT/station_env.sh"
else
    echo ">>> [ERROR] station_env.sh غير موجود!"
    exit 1
fi

# 2) قتل أي عمليات معلّقة
echo ">>> [STATION] Killing old processes ..."
pkill -f "uvicorn" 2>/dev/null || true
pkill -f "npm" 2>/dev/null || true
sleep 1

# 3) تشغيل الباك اند
echo ">>> [STATION] Starting backend ..."
cd "$BACK"
source .venv/bin/activate
nohup uvicorn app.main:app --host 0.0.0.0 --port 8810 \
    > "$ROOT/backend.log" 2>&1 &
BACKPID=$!
echo ">>> [STATION] Backend PID: $BACKPID"

# 4) تشغيل الفرونت اند
echo ">>> [STATION] Starting frontend ..."
cd "$FRONT"
nohup npm run dev -- --host 0.0.0.0 \
    > "$ROOT/frontend.log" 2>&1 &
FRONTPID=$!
echo ">>> [STATION] Frontend PID: $FRONTPID"

# 5) فتح المتصفح
sleep 1
termux-open-url "http://127.0.0.1:5173"

echo
echo ">>> [STATION] Station is running."
echo "    To stop: kill $BACKPID $FRONTPID"
