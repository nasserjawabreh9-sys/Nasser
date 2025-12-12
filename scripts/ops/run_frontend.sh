#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="${ROOT:-$HOME/station_root}"
cd "$ROOT/frontend"
npm run dev -- --host 127.0.0.1 --port 5173
