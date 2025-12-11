#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "===================================="
echo "   🚉 STATION – STRONG UI LAUNCH"
echo "===================================="

ROOT="$HOME/station_root"
cd "$ROOT"

echo
echo ">>> ضبط الترميزات (UTF-8) لهذه الجلسة..."
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

echo
echo ">>> تحميل station_env.sh إن وُجد..."
if [ -f "$ROOT/station_env.sh" ]; then
  source "$ROOT/station_env.sh"
  echo "[INFO] station_env.sh loaded."
else
  echo "[WARN] لا يوجد station_env.sh (مسموح الآن، سنتجاوز المفاتيح)."
fi

echo
echo ">>> فحص الباك-إند على 8810 ..."
if curl -s --max-time 2 http://127.0.0.1:8810/health >/dev/null 2>&1; then
  echo "✔ Backend already running on 8810."
else
  echo "✘ Backend not responding – تشغيل STATION عبر run_station.sh ..."
  if [ -f "$ROOT/run_station.sh" ]; then
    bash "$ROOT/run_station.sh"
  else
    echo "❌ لا يوجد run_station.sh في $ROOT"
    exit 1
  fi

  echo ">>> انتظار إقلاع الباك-إند..."
  for i in 1 2 3 4 5; do
    sleep 3
    if curl -s --max-time 2 http://127.0.0.1:8810/health >/dev/null 2>&1; then
      echo "✔ Backend is now up on 8810."
      break
    else
      echo "… ما زال يقلع (محاولة رقم $i)"
    fi
  done
fi

echo
echo ">>> اختبار سريع لواجهة /health:"
curl -s http://127.0.0.1:8810/health || echo "⚠ فشل الاتصال بـ /health (تأكد لاحقاً)."

echo
echo ">>> فتح واجهة STATION على 5173 ..."
if command -v termux-open-url >/dev/null 2>&1; then
  termux-open-url "http://127.0.0.1:5173/"
  echo "✔ تم إرسال الرابط للمتصفح (Chrome/متصفح النظام)."
else
  echo "⚠ لا يوجد termux-open-url – افتح الرابط يدويًا:"
  echo "   http://127.0.0.1:5173/"
fi

echo
echo "===================================="
echo "   ✅ DONE – UI SHOULD BE OPEN"
echo "===================================="
