#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=============================="
echo "     🚀 SVNL-9 QUICK RECOVERY"
echo "=============================="

ROOT="$HOME/station_root"

if [ ! -d "$ROOT" ]; then
    echo "✘ station_root غير موجود"
    exit 1
fi

cd "$ROOT"

echo
echo ">>> تحميل المفاتيح..."
if [ -f station_env.sh ]; then
    # معاملة الملف كـ UTF-8
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    source station_env.sh
    echo "✔ تم تحميل station_env.sh"
else
    echo "✘ station_env.sh غير موجود"
fi

echo
echo ">>> تشغيل الـ Backend..."
if [ -f run_backend.sh ]; then
    bash run_backend.sh
    sleep 2
    echo "✔ Backend attempt done"
else
    echo "✘ run_backend.sh غير موجود"
fi

echo
echo ">>> تشغيل الـ Frontend..."
if [ -f run_frontend.sh ]; then
    bash run_frontend.sh
    sleep 2
    echo "✔ Frontend attempt done"
else
    echo "✘ run_frontend.sh غير موجود"
fi

echo
echo ">>> فحص المنافذ..."
if command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 8810 && echo "✔ Backend 8810 شغّال" || echo "✘ Backend 8810 واقف"
    nc -z 127.0.0.1 5173 && echo "✔ Frontend 5173 شغّال" || echo "✘ Frontend 5173 واقف"
else
    echo "✘ nc غير مثبت (pkg install netcat-openbsd)"
fi

echo
echo ">>> العمليات:"
ps | grep -E "uvicorn|npm" | grep -v grep || echo "✘ لا يوجد عمليات"

echo
echo "=============================="
echo "     ✅ SVNL-9 FINISHED"
echo "=============================="
