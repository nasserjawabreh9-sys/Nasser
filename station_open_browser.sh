#!/data/data/com.termux/files/usr/bin/bash

URL="http://127.0.0.1:5173/"

echo ">>> فتح المتصفح على: $URL"

if command -v termux-open-url >/dev/null 2>&1; then
    termux-open-url "$URL"
else
    echo "⚠ جهازك لا يدعم termux-open-url"
    echo "افتح الرابط يدويًا: $URL"
fi

