#!/data/data/com.termux/files/usr/bin/bash

echo "==============================="
echo "   🚦 STATION QUICK CHECK"
echo "==============================="

ROOT="$HOME/station_root"

echo
echo ">>> ROOT:"
[ -d "$ROOT" ] && echo "✔ station_root موجود" || echo "✘ station_root غير موجود"

echo
echo ">>> ENV Variables:"
if [ -z "$STATION_OPENAI_API_KEY" ]; then
    echo "✘ STATION_OPENAI_API_KEY غير محمّل"
else
    echo "✔ STATION_OPENAI_API_KEY محمّل"
fi

if [ "$STATION_OPENAI_API_KEY" = "$OPENAI_API_KEY" ] && [ -n "$OPENAI_API_KEY" ]; then
    echo "✔ المفتاحان موحّدان"
else
    echo "✘ المفتاحان غير موحّدين"
fi

echo "LANG: $LANG"
echo "LC_ALL: $LC_ALL"

echo
echo ">>> BACKEND (port 8810):"
if nc -z 127.0.0.1 8810 2>/dev/null; then
    echo "✔ backend RUNNING"
else
    echo "✘ backend NOT running"
fi

echo
echo ">>> FRONTEND (port 5173):"
if nc -z 127.0.0.1 5173 2>/dev/null; then
    echo "✔ frontend RUNNING"
else
    echo "✘ frontend NOT running"
fi

echo
echo ">>> Processes:"
ps | grep -E "uvicorn|npm" | grep -v grep || echo "✘ لا يوجد عمليات"

echo
echo "==============================="
echo "   ✅ QUICK CHECK FINISHED"
echo "==============================="
