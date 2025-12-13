#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
BASE="${1:-http://127.0.0.1:8000}"

echo "== SMOKE: health =="
curl -s "$BASE/health" | cat
echo
echo "== SMOKE: info =="
curl -s "$BASE/info" | cat
echo
echo "== SMOKE: version =="
curl -s "$BASE/version" | cat
echo
