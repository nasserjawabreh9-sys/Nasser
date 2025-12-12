#!/data/data/com.termux/files/usr/bin/bash
set -e

cmd="${1:-}"
shift || true

case "$cmd" in
  dynamo)
    sub="${1:-}"
    shift || true
    case "$sub" in
      start)
        mode="${1:-TRIAL-1}"
        pipeline="${2:-bootstrap_validate}"
        root="${3:-1000}"
        python scripts/ops/dynamo.py "$mode" "$pipeline" "$root"
        ;;
      *)
        echo "Usage: st dynamo start <MODE> <PIPELINE> [ROOT_ID]"
        echo "Example: st dynamo start TRIAL-1 bootstrap_validate 1000"
        exit 1
        ;;
    esac
    ;;
  *)
    echo "Usage: st <command>"
    echo "Commands:"
    echo "  dynamo start <MODE> <PIPELINE> [ROOT_ID]"
    exit 1
    ;;
esac


if [ "$cmd" = "rooms" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    run)
      mode="${1:-PROD}"; root="${2:-1400}"; workers="${3:-3}"
      python scripts/rooms/room_runner.py "$mode" "$root" "$workers"
      ;;
    *)
      echo "Usage: st rooms run <MODE> <ROOT_ID> [MAX_WORKERS]"
      echo "Example: st rooms run PROD 1400 3"
      exit 1
      ;;
  esac
  exit 0
fi

if [ "$cmd" = "guard" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    tree)
      bash scripts/guards/guard_tree_bindings.sh
      ;;
    *)
      echo "Usage: st guard tree"
      exit 1
      ;;
  esac
  exit 0
fi

if [ "$cmd" = "queue" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    autodiff)
      python scripts/ops/diff_to_queue.py
      ;;
    run)
      export ST_MODE="${1:-PROD}"
      export ST_ROOT="${2:-1500}"
      python scripts/ops/queue_runner.py
      ;;
    *)
      echo "Usage: st queue autodiff"
      echo "       st queue run <MODE> <ROOT_ID>"
      exit 1
      ;;
  esac
  exit 0
fi

if [ "$cmd" = "locks" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    clean)
      python scripts/ops/lock_cleaner.py
      ;;
    *)
      echo "Usage: st locks clean"
      exit 1
      ;;
  esac
  exit 0
fi

if [ "$cmd" = "queue2" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    run)
      export ST_MODE="${1:-PROD}"
      python scripts/ops/queue_runner_v2.py
      ;;
    *)
      echo "Usage: st queue2 run <MODE>"
      exit 1
      ;;
  esac
  exit 0
fi

if [ "$cmd" = "merge" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    gate)
      bash scripts/ops/merge_gate.sh
      ;;
    *)
      echo "Usage: st merge gate"
      exit 1
      ;;
  esac
  exit 0
fi

if [ "$cmd" = "rooms" ]; then
  sub="${1:-}"; shift || true
  case "$sub" in
    show)
      cat station_meta/concurrency/rooms.json
      ;;
    *)
      echo "Usage: st rooms show"
      exit 1
      ;;
  esac
  exit 0
fi
