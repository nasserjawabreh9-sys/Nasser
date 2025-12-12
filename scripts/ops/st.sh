#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

cmd="${1:-}"
shift || true

if [ -z "$cmd" ]; then
  echo "Usage: bash scripts/ops/st.sh <command> ..."
  echo "Commands: dynamo"
  exit 1
fi

if [ "$cmd" = "dynamo" ]; then
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
      echo "Usage: bash scripts/ops/st.sh dynamo start <MODE> <PIPELINE> [ROOT_ID]"
      echo "Example: bash scripts/ops/st.sh dynamo start TRIAL-1 bootstrap_validate 1000"
      exit 1
      ;;
  esac
  exit 0
fi

echo "Unknown command: $cmd"
exit 1
