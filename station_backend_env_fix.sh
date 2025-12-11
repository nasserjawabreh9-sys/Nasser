#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "===================================="
echo "  🛠 STATION BACKEND ENV FIX"
echo "  (إعادة ضبط venv + requirements)"
echo "===================================="

ROOT="$HOME/station_root"
BACK="$ROOT/backend"

if [ ! -d "$BACK" ]; then
  echo "✘ backend غير موجود في: $BACK"
  exit 1
fi

echo
echo ">>> كتابة requirements.txt بنسخ متوافقة مع Pydantic v1…"
cat > "$BACK/requirements.txt" << 'EOF'
fastapi==0.103.2
uvicorn==0.23.2
pydantic==1.10.13
EOF

echo
echo ">>> إزالة venv القديم إن وجد…"
cd "$BACK"
rm -rf .venv

echo
echo ">>> إنشاء venv جديد…"
python -m venv .venv

echo
echo ">>> تفعيل venv وتحديث pip…"
source .venv/bin/activate
pip install --upgrade pip wheel setuptools

echo
echo ">>> تثبيت المتطلبات من requirements.txt…"
pip install -r requirements.txt

echo
echo "===================================="
echo "  ✅ ENV FIX DONE"
echo "  - venv جديد جاهز"
echo "  - fastapi + uvicorn + pydantic v1 مثبّتة"
echo "  (لا يوجد تشغيل للسيرفر في هذا السكربت)"
echo "===================================="
