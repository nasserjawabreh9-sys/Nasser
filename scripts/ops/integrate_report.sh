#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
OUT="$ROOT/station_meta/integrate/integrate_${TS}.txt"
mkdir -p "$ROOT/station_meta/integrate"

{
  echo "INTEGRATE_REPORT ts=$TS"
  echo
  echo "[TREE]"
  ls -la "$ROOT/station_meta/tree" || true
  echo
  echo "[ROOMS]"
  ls -la "$ROOT/station_meta/rooms" || true
  echo
  echo "[GUARDS]"
  ls -la "$ROOT/scripts/guards" || true
  echo
  echo "[DYNAMO]"
  ls -la "$ROOT/scripts/ops" || true
} > "$OUT"

echo ">>> [integrate_report] wrote $OUT"
