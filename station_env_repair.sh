#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
cd "$ROOT"

echo ">>> [ENV-REPAIR] تحميل القيم القديمة من station_env.sh (لو موجود)..."

OLD_API_KEY=""
OLD_GH_TOKEN=""

if [ -f station_env.sh ]; then
  # نعمل source للملف القديم داخل سكربت فقط
  # عشان نجيب القيم اللي انت خزنتها بالنانو
  source station_env.sh

  OLD_API_KEY="$STATION_OPENAI_API_KEY"
  OLD_GH_TOKEN="$GITHUB_TOKEN"
fi

echo "    STATION_OPENAI_API_KEY(old) = ${OLD_API_KEY:0:8}..."
echo "    GITHUB_TOKEN(old)          = ${OLD_GH_TOKEN:0:6}..."

if [ -z "$OLD_API_KEY" ]; then
  echo "✘ ما قدرنا نقرأ STATION_OPENAI_API_KEY من الملف القديم."
  echo "  افتح station_env.sh بالنانو وتأكد إنه فيه المفتاح، ثم أعد تشغيل هذا السكربت."
  exit 1
fi

cat > station_env.sh << EOF
#!/data/data/com.termux/files/usr/bin/bash

# نفس المفتاح للمحطّة ولأي كود يستخدم OPENAI_API_KEY
export STATION_OPENAI_API_KEY="$OLD_API_KEY"
export OPENAI_API_KEY="$OLD_API_KEY"

# توكن جت هب (نفس القديم)
export GITHUB_TOKEN="$OLD_GH_TOKEN"

# إجبار UTF-8 عشان ما ترجع لنا UnicodeEncodeError
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"

echo "[station_env] Loaded (unified keys + UTF-8)."
EOF

chmod +x station_env.sh

echo ">>> [ENV-REPAIR] تم إصلاح station_env.sh وتوحيد المفاتيح وضبط UTF-8."
echo ">>> فعّل الملف الآن في هذه الجلسة:"
echo "    source station_env.sh"
