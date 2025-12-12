#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
RID="${1:-}"; shift || true
MSG="${1:-}"; shift || true
bash scripts/ops/stage_commit_push.sh "$RID" "${MSG:-[R${RID}] autopush}"
