#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
BASE="${1:-http://127.0.0.1:8000}"
EDIT="${2:-1234}"

echo "== health =="; curl -s "$BASE/health"; echo
echo "== info =="; curl -s "$BASE/info"; echo
echo "== version =="; curl -s "$BASE/version"; echo
echo "== ops git status =="; curl -s -X POST "$BASE/ops/git/status" -H "x-edit-key: $EDIT" -H "Content-Type: application/json" -d '{}'; echo
