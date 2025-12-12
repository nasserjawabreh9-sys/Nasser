#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "== r9600 release start =="
echo "[1/7] Verify repo..."
test -d .git || { echo "ERROR: not a git repo"; exit 1; }

echo "[2/7] Ensure VERSION exists..."
test -f VERSION || { echo "ERROR: VERSION missing"; exit 1; }

VER="$(cat VERSION | tr -d '\r\n')"
if [[ "$VER" != "r9600" ]]; then
  echo "ERROR: VERSION is '$VER' not 'r9600'"
  exit 1
fi

echo "[3/7] Quick tree snapshot..."
git status --porcelain || true

echo "[4/7] Commit..."
git add -A
git commit -m "release: r9600 baseline" || echo "NOTE: nothing to commit"

echo "[5/7] Tag..."
git tag -f "r9600" || true

echo "[6/7] Push..."
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
git push -u origin "$BRANCH"
git push -f origin "r9600"

echo "[7/7] Done."
echo "== r9600 release complete =="
