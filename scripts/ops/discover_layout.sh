#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "=== STATION LAYOUT DISCOVERY ==="
echo "[1] Top-level:"
ls -la

echo
echo "[2] Backend candidates:"
find backend -maxdepth 5 -type f \( -name "main.py" -o -name "app.py" -o -name "asgi.py" -o -name "wsgi.py" \) 2>/dev/null | sed 's/^/ - /' || true

echo
echo "[3] Backend python package roots (looking for __init__.py):"
find backend -maxdepth 4 -type f -name "__init__.py" 2>/dev/null | head -n 30 | sed 's/^/ - /' || true

echo
echo "[4] Routes-like files (keyword Route|router|APIRouter):"
grep -RIn --exclude-dir=.venv --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
  -E "Route\\(|APIRouter\\(|router\\s*=|routes\\s*=\\s*\\[" backend 2>/dev/null | head -n 80 || true

echo
echo "[5] Frontend candidates:"
find frontend -maxdepth 4 -type f \( -name "package.json" -o -name "vite.config.*" -o -name "index.html" \) 2>/dev/null | sed 's/^/ - /' || true

echo
echo "[6] Frontend src tree:"
find frontend -maxdepth 5 -type d -name "src" 2>/dev/null | sed 's/^/ - /' || true

echo
echo "[7] Settings page candidates:"
grep -RIn --exclude-dir=node_modules --exclude-dir=dist --exclude-dir=build \
  -E "function\\s+Settings|export\\s+default\\s+function\\s+Settings|Settings\\s*\\(" frontend 2>/dev/null | head -n 80 || true

echo
echo "=== DONE ==="
