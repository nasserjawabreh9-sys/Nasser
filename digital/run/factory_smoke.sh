#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
echo "==[FACTORY SMOKE]=="
curl -s http://127.0.0.1:8000/health; echo
curl -s -X POST http://127.0.0.1:8000/uul/factory/run -H "x-edit-key: 1234"; echo
sleep 1
curl -s "http://127.0.0.1:8000/uul/factory/status?tail=200" | cat; echo
