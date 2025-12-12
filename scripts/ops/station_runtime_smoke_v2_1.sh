#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
BASE="${1:-http://127.0.0.1:8000}"

echo "== SMOKE: health =="
curl -s "$BASE/health" | cat
echo
echo "== SMOKE: rooms list =="
curl -s "$BASE/rooms" | cat
echo
echo "== SMOKE: ai route =="
curl -s -X POST "$BASE/ai/route" -H "Content-Type: application/json" -d '{"room_id":"9001","text":"smoke v2.1"}' | cat
echo
