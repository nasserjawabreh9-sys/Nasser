#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "======================================="
echo "       STATION STATUS CHECK"
echo "======================================="

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
FRONT="$ROOT/frontend"
WORK="$ROOT/workspace"

echo
echo ">>> ROOT folder:"
if [ -d "$ROOT" ]; then
  echo "    ✔ موجود: $ROOT"
else
  echo "    ✘ غير موجود"
fi

echo
echo ">>> Structure:"
[ -d "$BACK" ] && echo "    ✔ backend موجود" || echo "    ✘ backend ناقص"
[ -d "$FRONT" ] && echo "    ✔ frontend موجود" || echo "    ✘ frontend ناقص"
[ -d "$WORK" ] && echo "    ✔ workspace جاهز" || echo "    ✘ workspace ناقص"

echo
echo ">>> Environment Variables (current shell):"
if [ -z "$OPENAI_API_KEY" ]; then
  echo "    ✘ OPENAI_API_KEY غير محمّل"
else
  echo "    ✔ OPENAI_API_KEY محمّل"
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "    ✘ GITHUB_TOKEN غير محمّل"
else
  echo "    ✔ GITHUB_TOKEN محمّل"
fi

echo
echo ">>> Checking backend port (8810):"
if command -v nc >/dev/null 2>&1 && nc -z 127.0.0.1 8810 2>/dev/null; then
  echo "    ✔ BACKEND RUNNING على 8810"
else
  echo "    ✘ backend مش شغّال"
fi

echo
echo ">>> Checking frontend port (5173):"
if command -v nc >/dev/null 2>&1 && nc -z 127.0.0.1 5173 2>/dev/null; then
  echo "    ✔ FRONTEND RUNNING على 5173"
else
  echo "    ✘ frontend مش شغّال"
fi

echo
echo ">>> Running processes (uvicorn/npm):"
ps | grep -E "uvicorn|npm" | grep -v grep || echo "    ✘ لا يوجد عمليات شغّالة"

echo
echo "======================================="
echo "      STATUS CHECK FINISHED"
echo "======================================="
