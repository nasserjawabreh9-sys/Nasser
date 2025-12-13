#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

ROOT="$HOME/station_root"
AUD="$ROOT/scripts/uul_950_nuke_audit_report.sh"

if [ ! -f "$AUD" ]; then
  echo "ERROR: missing $AUD"
  exit 1
fi

# Replace /healthz -> /health (Termux-safe sed)
tmp="$AUD.tmp"
cat "$AUD" \
  | sed 's|/healthz|/health|g' \
  > "$tmp"

mv "$tmp" "$AUD"
chmod +x "$AUD"

echo "OK: patched audit script to use /health"
echo "NEXT: run => $AUD"
