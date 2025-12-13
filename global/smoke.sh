#!/data/data/com.termux/files/usr/bin/bash
set -e
API="http://127.0.0.1:8000"
echo "== health =="; curl -s "$API/health"; echo
echo "== info =="; curl -s "$API/info"; echo
echo "== version =="; curl -s "$API/version"; echo
echo "== global rooms =="; curl -s "$API/global/rooms"; echo
