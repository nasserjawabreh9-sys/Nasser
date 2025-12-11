#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"

if [ ! -d "$ROOT" ]; then
  echo "✘ station_root غير موجود عند: $ROOT"
  exit 1
fi

cd "$ROOT"

echo ">>> [STATION-ULT] تأكيد المجلدات الأساسية..."
mkdir -p backend/logs
mkdir -p frontend
mkdir -p workspace/snippets
mkdir -p workspace/prompts
mkdir -p workspace/scripts
mkdir -p exports

echo ">>> [STATION-ULT] كتابة station_manifest.json..."
cat > station_manifest.json << 'JSON'
{
  "name": "STATION",
  "description": "Minimal bridge between backend & frontend (Termux edition) with workspace.",
  "version": "0.3.0",
  "root": "./",
  "backend": {
    "lang": "python",
    "framework": "fastapi",
    "entry": "backend/app/main.py",
    "run_script": "run_backend.sh",
    "port": 8810,
    "features": ["health", "echo", "chat", "workspace"]
  },
  "frontend": {
    "framework": "react+vite",
    "entry": "frontend/src/App.tsx",
    "dev_script": "npm run dev",
    "port": 5173,
    "features": ["health-panel", "echo-ui", "chat-ui", "workspace-ui"]
  },
  "workspace": {
    "root": "workspace",
    "folders": ["snippets", "prompts", "scripts"],
    "notes": "يُستخدم لتخزين النصوص والأوامر والأكواد الخفيفة."
  },
  "tools": {
    "doctor": "station_doctor.sh",
    "quick_check": "station_quick_check.sh",
    "launcher": "run_station.sh"
  }
}
JSON

echo ">>> [STATION-ULT] كتابة README_STATION.md..."
cat > README_STATION.md << 'MD'
# STATION – Termux Edition

محطة مصغّرة للربط بين الباك-إند (FastAPI) والفرونت (React+Vite) مع Workspace بسيط.

## الهيكل الأساسي

- \`backend/\`
  - \`app/main.py\`  → نقاط: \`/health\`, \`/api/echo\`, \`/api/chat\` (تجريبي), \`/api/workspace/*\`
  - \`.venv/\`       → بيئة بايثون الافتراضية
  - \`run_backend.sh\`
  - \`logs/\`        → سجلات تشغيل (لاحقًا عند الحاجة)

- \`frontend/\`
  - \`src/App.tsx\`  → واجهة واحدة تعرض: Health, Echo, Chat, Workspace
  - \`node_modules/\`
  - \`vite.config.ts\`

- \`workspace/\`
  - \`snippets/\`    → مقاطع كود/أوامر
  - \`prompts/\`     → نصوص جاهزة/أسئلة
  - \`scripts/\`     → سكربتات صغيرة
  - ملفات حرة مثل \`note1.txt\`, \`todo.md\`...

- سكربتات عامة في الجذر:
  - \`run_station.sh\`          → تشغيل الباك-إند + الفرونت
  - \`station_env.sh\`          → تحميل المفاتيح (يمكن تأجيلها)
  - \`station_doctor.sh\`       → فحص شامل
  - \`station_quick_check.sh\`  → فحص سريع
  - \`station_manifest.json\`   → وصف المنظومة

## المبدأ

- بناء تدريجي، بدون تعقيد أو اعتماد على خدمات خارجية في البداية.
- التركيز على:
  1. صحّة البنية (Structure)
  2. وضوح الملفات
  3. قابلية النقل والنسخ الاحتياطي

MD

echo ">>> [STATION-ULT] إعداد .gitignore (إن لم يكن موجودًا)..."
if [ ! -f ".gitignore" ]; then
  cat > .gitignore << 'GI'
# Python
backend/.venv/
__pycache__/
*.pyc

# Node / Frontend
frontend/node_modules/
frontend/dist/

# Logs
*.log
backend/logs/

# Backups / Exports
exports/
station_root_*.tar.gz
station_backups/
GI
else
  echo "    .gitignore موجود مسبقًا، لم يتم استبداله."
fi

echo ">>> [STATION-ULT] انتهى إعداد STATION ULTIMATE BASE."
echo "    - station_manifest.json جاهز"
echo "    - README_STATION.md جاهز"
echo "    - workspace/ مُنظّم"
