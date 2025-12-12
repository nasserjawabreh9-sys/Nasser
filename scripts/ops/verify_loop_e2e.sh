#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo "=== HEALTH ==="
curl -sS http://127.0.0.1:8000/health && echo

echo
echo "=== SETTINGS (GET /api/settings) ==="
curl -sS http://127.0.0.1:8000/api/settings | head -c 600 && echo

echo
echo "=== LOOP: submit task ==="
curl -sS -X POST http://127.0.0.1:8000/api/loop/task \
  -H "Content-Type: application/json" \
  -d '{"kind":"echo","payload":{"msg":"hello_loop"}}' && echo

echo
echo "=== LOOP: run once ==="
curl -sS -X POST http://127.0.0.1:8000/api/loop/run_once && echo

echo
echo "=== LOOP: list tasks tail ==="
curl -sS "http://127.0.0.1:8000/api/loop/tasks?limit=20" | head -c 900 && echo

echo
echo "DONE."
