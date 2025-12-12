#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$HOME/station_root"

cmd="${1:-}"; shift || true

case "$cmd" in
  tree)
    sub="${1:-}"; shift || true
    case "$sub" in
      update) bash scripts/tree_authority/tree_update.sh ;;
      broadcast) bash scripts/tree_authority/tree_broadcast.sh ;;
      *) echo "Usage: st tree {update|broadcast}"; exit 1 ;;
    esac
    ;;
  rooms)
    sub="${1:-}"; shift || true
    case "$sub" in
      broadcast) bash scripts/rooms/rooms_broadcast.sh ;;
      *) echo "Usage: st rooms {broadcast}"; exit 1 ;;
    esac
    ;;
  guards)
    bash scripts/guards/guard_tree_fresh.sh
    bash scripts/guards/guard_rooms_broadcast.sh
    bash scripts/guards/guard_termux_safe_deps.sh
    ;;
  integrate)
    bash scripts/ops/integrate_report.sh
    ;;
  dynamo)
    sub="${1:-}"; shift || true
    case "$sub" in
      start)
        mode="${1:-PROD}"; pipeline="${2:-bootstrap_validate}"; root="${3:-1000}"
        python scripts/ops/dynamo.py "$mode" "$pipeline" "$root"
        ;;
      *) echo "Usage: st dynamo start <MODE> <PIPELINE> [ROOT_ID]"; exit 1 ;;
    esac
    ;;
  push)
    rid="${1:-9000}"; shift || true
    msg="${1:-[R${rid}] push}"; shift || true
    bash scripts/ops/stage_commit_push.sh "$rid" "$msg"
    ;;
  *)
    echo "Usage:"
    echo "  st tree update|broadcast"
    echo "  st rooms broadcast"
    echo "  st guards"
    echo "  st integrate"
    echo "  st dynamo start <MODE> <PIPELINE> [ROOT_ID]"
    echo "  st push <ROOT_ID> \"message\""
    exit 1
    ;;
esac
