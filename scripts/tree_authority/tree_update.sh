#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

mkdir -p station_meta/tree station_meta/bindings

# Simple tree snapshot (Termux-safe)
# Exclude venv/node_modules/.git to keep it readable
find . -maxdepth 5 \
  -path './.git' -prune -o \
  -path './backend/.venv' -prune -o \
  -path './frontend/node_modules' -prune -o \
  -path './frontend/dist' -prune -o \
  -print \
| sed 's|^\./||' \
| sort > station_meta/tree/tree_paths.txt

# Minimal bindings snapshot (fill later if needed)
cat > station_meta/bindings/bindings.json << 'JSON'
{
  "version": "0.1.0",
  "notes": "bindings snapshot placeholder",
  "backend": {"port": 8000, "health": "/health"},
  "frontend": {"dev_port": 5173}
}
JSON

echo ">>> [tree_update] wrote station_meta/tree/tree_paths.txt and station_meta/bindings/bindings.json"
