#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

echo ">>> [merge_gate] running stop-the-world checks..."

# Guard must pass
bash scripts/guards/guard_ops_gate.sh

# If processed has failures -> block
PROCESSED="station_meta/queue/processed.jsonl"
if [ -f "$PROCESSED" ]; then
  if grep -q '"status":"failed"' "$PROCESSED"; then
    echo "☠️ [merge_gate] BLOCKED: found failed tasks in processed queue."
    echo "Fix failures then rerun queue."
    exit 93
  fi
fi

echo ">>> [merge_gate] OK"
