#!/data/data/com.termux/files/usr/bin/bash

ROOT="$HOME/station_root"

echo "==============================="
echo "   🌳 STATION TREE (depth 3)"
echo "==============================="
echo

if [ ! -d "$ROOT" ]; then
  echo "✘ station_root غير موجود عند: $ROOT"
  exit 1
fi

cd "$ROOT"

echo ">>> الجذر: $ROOT"
echo

# نعرض كل شيء حتى عمق 3
find . -maxdepth 3 -print | sed 's|^\./||' | sort

echo
echo "==============================="
echo "   ✅ TREE DONE"
echo "==============================="
