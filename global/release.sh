#!/data/data/com.termux/files/usr/bin/bash
set -e
ROOT="$HOME/station_root"
echo "== smoke =="
"$ROOT/global/smoke.sh"
echo "== publish =="
"$ROOT/global/loop6_publish.sh"
