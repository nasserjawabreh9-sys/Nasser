#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
echo "==[DIGITAL CHECKS]=="
echo "[tree]"; ls -la "$ROOT" | head
echo "[identity]"; ls -la "$ROOT/digital" | head
echo "[backend uul_core]"; ls -la "$ROOT/backend/uul_core" | head
echo "[health]"; curl -s http://127.0.0.1:8000/health || echo "backend not running"
echo
echo "[uul factory status]"; curl -s "http://127.0.0.1:8000/uul/factory/status?tail=40" || true
echo
