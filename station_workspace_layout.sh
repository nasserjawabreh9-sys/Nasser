#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "===================================="
echo "  📂 STATION WORKSPACE LAYOUT"
echo "===================================="

ROOT="$HOME/station_root"
WORK="$ROOT/workspace"

mkdir -p "$WORK/out"
mkdir -p "$WORK/scripts"
mkdir -p "$WORK/snippets"

# README بسيط
cat > "$WORK/README.md" << 'EOF'
STATION WORKSPACE

- loop_messages.json  : سجل رسائل LOOP (user/station)
- plan.json           : خطة مبنية من الرسائل
- out/                : ملفات ناتجة من /api/actions/run
- scripts/            : سكربتات مساعدة (داخلي)
- snippets/           : قصاصات/نصوص لاحقًا

هذه المجلدات جزء من LOOP الداخلي، بدون مفاتيح وبدون تشغيل إجباري.
EOF

touch "$WORK/out/.gitkeep" "$WORK/scripts/.gitkeep" "$WORK/snippets/.gitkeep"

echo
echo "  ✅ WORKSPACE جاهز تحت:"
echo "     $WORK"
echo "===================================="
