#!/data/data/com.termux/files/usr/bin/bash
set -e

# ==== Station Environment (local only, DO NOT COMMIT REAL KEYS) ====

# ضع مفتاح STATION/OpenAI يدويًا عند التشغيل أو من خارج git
# مثال وقت التشغيل:
#   export STATION_OPENAI_API_KEY="sk-XXXX..."
# ثم:
#   source ~/station_root/station_env.sh
export STATION_OPENAI_API_KEY="${STATION_OPENAI_API_KEY:-}"
export OPENAI_API_KEY="$STATION_OPENAI_API_KEY"

# ضع GitHub Token يدويًا عند الحاجة:
#   export GITHUB_TOKEN="ghp_XXXX..."
# قبل تشغيل أي سكربت يحتاج GitHub
export GITHUB_TOKEN="${GITHUB_TOKEN:-}"

echo ">>> [STATION] Environment loaded:"
echo "    OPENAI_API_KEY          = ${OPENAI_API_KEY:+set (from env)}"
echo "    STATION_OPENAI_API_KEY  = ${STATION_OPENAI_API_KEY:+set (from env)}"
echo "    GITHUB_TOKEN            = ${GITHUB_TOKEN:+set (from env)}"

