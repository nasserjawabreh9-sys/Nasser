#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "===================================="
echo "   STATION STRUCTURE – BUILD V2"
echo "===================================="

ROOT="$HOME/station_root"
BACK="$ROOT/backend"
FRONT="$ROOT/frontend"
WORK="$ROOT/workspace"

echo
echo ">>> إنشاء المجلدات…"
mkdir -p "$BACK/app"
mkdir -p "$BACK/loop_actions"
mkdir -p "$BACK/utils"

mkdir -p "$FRONT/src"
mkdir -p "$FRONT/src/components"
mkdir -p "$FRONT/src/api"
mkdir -p "$FRONT/public"

mkdir -p "$WORK"

echo
echo ">>> إنشاء ملفات backend الفارغة…"
touch "$BACK/app/__init__.py"
touch "$BACK/app/main.py"
touch "$BACK/loop_actions/__init__.py"
touch "$BACK/utils/__init__.py"
touch "$BACK/requirements.txt"
touch "$BACK/run_backend.sh"

echo
echo ">>> إنشاء ملفات frontend الفارغة…"
touch "$FRONT/index.html"
touch "$FRONT/package.json"
touch "$FRONT/vite.config.ts"
touch "$FRONT/src/main.tsx"
touch "$FRONT/src/App.tsx"
touch "$FRONT/src/api/station_api.ts"

echo
echo ">>> ملفات جذر STATION…"
touch "$ROOT/run_station.sh"
touch "$ROOT/station_env.sh"
touch "$ROOT/station_doctor.sh"
touch "$ROOT/station_quick_check.sh"
touch "$ROOT/README.md"

echo
echo "===================================="
echo "   ✅ STRUCTURE READY (V2)"
echo "===================================="
