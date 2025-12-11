#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "===================================="
echo "   🚀 STATION – RUN & TEST"
echo "===================================="

ROOT="$HOME/station_root"
cd "$ROOT"

echo
echo ">>> تشغيل STATION عبر run_station.sh ..."
bash run_station.sh

echo
echo ">>> إعطاء السيرفر ثوانٍ ليقلع..."
sleep 8

echo
echo ">>> فحص /health ..."
curl -s http://127.0.0.1:8810/health || echo "❌ health call failed"

echo
echo ">>> تجربة /api/chat برسالة عربية (UTF-8) ..."
curl -s -X POST http://127.0.0.1:8810/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"مرحبا يا ستيشن، هذا اختبار UTF-8"}' \
  || echo "❌ chat call failed"

echo
echo ">>> تلميح:"
echo "    لفتح الواجهة في المتصفح:"
echo "    termux-open-url http://127.0.0.1:5173/"

echo
echo "انتهى السكربت. إذا ظهرت JSON نظيفة فوق، فـ STATION تعمل بشكل سليم."
echo "===================================="
