#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
BACKUP_DIR="$HOME/station_backups"

if [ ! -d "$ROOT" ]; then
  echo "✘ station_root غير موجود عند: $ROOT"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

STAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE="$BACKUP_DIR/station_root_$STAMP.tar.gz"

echo ">>> [STATION-BACKUP] إنشاء نسخة احتياطية..."
echo "    الجذر : $ROOT"
echo "    النسخة: $ARCHIVE"

tar -czf "$ARCHIVE" \
  --exclude='station_root/backend/.venv' \
  --exclude='station_root/frontend/node_modules' \
  -C "$HOME" station_root

echo ">>> [STATION-BACKUP] تم إنشاء النسخة بنجاح."
echo "    الملف : $ARCHIVE"
