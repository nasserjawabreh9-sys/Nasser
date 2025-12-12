#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
ROOT="$HOME/station_root"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DIR="$ROOT/station_meta/rooms"
mkdir -p "$DIR"

# 5 Rooms (can grow later)
cat > "$DIR/room_01_tree_authority.json" << 'JSON'
{"room":"tree_authority","scope":"tree_update + bindings + stamps + broadcast","outputs":["station_meta/tree/*","station_meta/bindings/bindings.json"]}
JSON
cat > "$DIR/room_02_guards.json" << 'JSON'
{"room":"guards","scope":"block bad deps + require tree fresh + require rooms broadcast + root id discipline","outputs":["scripts/guards/*","station_meta/guards/policy.json"]}
JSON
cat > "$DIR/room_03_dynamo_ops.json" << 'JSON'
{"room":"dynamo_ops","scope":"pipelines + locks + events + stage push","outputs":["scripts/ops/dynamo.py","station_meta/dynamo/dynamo_config.json","station_meta/dynamo/events.jsonl"]}
JSON
cat > "$DIR/room_04_backend.json" << 'JSON'
{"room":"backend","scope":"backend skeleton + health endpoint + safe deps","outputs":["backend/app/*","backend/requirements.txt"]}
JSON
cat > "$DIR/room_05_frontend.json" << 'JSON'
{"room":"frontend","scope":"frontend skeleton + api client + official UI later","outputs":["frontend/src/*"]}
JSON

echo "$TS" > "$DIR/last_broadcast.txt"
echo ">>> [rooms_broadcast] OK rooms_count=5"
