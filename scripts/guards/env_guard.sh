#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

# skeleton: requirements must exist; forbid uvicorn[standard] for Termux
if [ ! -f backend/requirements.txt ]; then
  echo "GUARD_FAIL: REQUIREMENTS_MISSING"
  exit 12
fi

if grep -qE 'uvicorn\[standard\]' backend/requirements.txt; then
  echo "GUARD_FAIL: UVICORN_STANDARD_FORBIDDEN_TERMUX"
  exit 13
fi

echo "GUARD_OK: ENV_POLICY"
