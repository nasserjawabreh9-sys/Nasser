#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
ENV_FILE="$ROOT/station_env.sh"

echo "===================================="
echo "   🔐 STATION ENV FIX – KEYS + UTF8"
echo "===================================="

if [ ! -f "$ENV_FILE" ]; then
    echo "✘ لا يوجد station_env.sh – سيتم إنشاء قالب بسيط"
    cat > "$ENV_FILE" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

# ضع القيم الحقيقية مكان النصوص التالية عبر nano
export STATION_OPENAI_API_KEY="PUT_STATION_KEY_HERE"
export GITHUB_TOKEN="PUT_GITHUB_TOKEN_HERE"

echo "[station_env] Loaded."
EOF
    chmod +x "$ENV_FILE"
    echo "✔ تم إنشاء station_env.sh مبدئيًا – عدّل المفاتيح يدويًا ثم أعد تشغيل هذا السكربت."
    exit 0
fi

echo "✔ station_env.sh موجود: $ENV_FILE"

# نضيف بلوك التوحيد + UTF-8 إذا غير موجود
if ! grep -q "AUTO-APPEND: station key unification" "$ENV_FILE"; then
    echo ">>> إضافة بلوك التوحيد + UTF-8 إلى station_env.sh (مرة واحدة)…"
    cat >> "$ENV_FILE" << 'EOF'

# === AUTO-APPEND: station key unification & UTF-8 (DO NOT EDIT ABOVE) ===
# ضبط الترميز
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
export PYTHONIOENCODING="utf-8"

# توحيد المفاتيح: نجعل OPENAI_API_KEY = STATION_OPENAI_API_KEY
export OPENAI_API_KEY="$STATION_OPENAI_API_KEY"
# === END AUTO-APPEND ===
EOF
else
    echo "✔ بلوك التوحيد + UTF-8 موجود مسبقًا – لن نكرره."
fi

chmod +x "$ENV_FILE"

echo ">>> تحميل station_env.sh في هذه الجلسة…"
# نحمّل المتغيرات في نفس الشل
source "$ENV_FILE"

echo
echo ">>> ملخص الحالة بعد التحميل:"
if [ -n "$STATION_OPENAI_API_KEY" ]; then
    echo "✔ STATION_OPENAI_API_KEY محمّل (الطول: ${#STATION_OPENAI_API_KEY})"
else
    echo "✘ STATION_OPENAI_API_KEY غير مضبوط داخل station_env.sh"
fi

if [ -n "$OPENAI_API_KEY" ]; then
    echo "✔ OPENAI_API_KEY محمّل (الطول: ${#OPENAI_API_KEY})"
else
    echo "✘ OPENAI_API_KEY غير مضبوط (راجع البلوك المضاف في آخر station_env.sh)"
fi

if [ "$STATION_OPENAI_API_KEY" = "$OPENAI_API_KEY" ] && [ -n "$OPENAI_API_KEY" ]; then
    echo "✔ المفتاحان موحَّدان فعليًا."
else
    echo "✘ المفتاحان غير متطابقين – تأكد أن STATION_OPENAI_API_KEY فيه القيمة الصحيحة."
fi

echo
echo "LANG = $LANG"
echo "LC_ALL = $LC_ALL"
echo "PYTHONIOENCODING = $PYTHONIOENCODING"

echo
echo "===================================="
echo "   ✅ ENV FIX DONE – READY"
echo "===================================="
