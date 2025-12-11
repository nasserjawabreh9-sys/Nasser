#!/data/data/com.termux/files/usr/bin/bash
set -e

ROOT="$HOME/station_root"
ENVFILE="$ROOT/station_env.sh"

echo ">>> [STATION] Auto-fix station_env.sh using current ENV ..."

# لازم يكونوا محمّلين من قبل بـ source station_env.sh
if [ -z "$STATION_OPENAI_API_KEY" ]; then
  echo "✘ STATION_OPENAI_API_KEY مش موجود في ENV."
  echo "   شغّل:  source \$ENVFILE  وبعدين أعد تشغيل هذا السكربت."
  exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "✘ GITHUB_TOKEN مش موجود في ENV."
  echo "   شغّل:  source \$ENVFILE  وبعدين أعد تشغيل هذا السكربت."
  exit 1
fi

cat > "$ENVFILE" << EOF
#!/data/data/com.termux/files/usr/bin/bash
# Station ENV – auto generated (UTF-8 + unified keys)

########################################
# 1) FORCE UTF-8 LOCALE
########################################
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export PYTHONIOENCODING="utf-8"

########################################
# 2) API KEYS (مأخوذة تلقائياً من ENV)
########################################

# مفتاح المشروع (ستايشن)
export STATION_OPENAI_API_KEY="$STATION_OPENAI_API_KEY"

# توحيد المفتاحين: نخلي OPENAI_API_KEY = STATION_OPENAI_API_KEY
export OPENAI_API_KEY="\$STATION_OPENAI_API_KEY"

# GitHub token
export GITHUB_TOKEN="$GITHUB_TOKEN"

echo "[station_env] Loaded (UTF-8 + keys unified)."
EOF

chmod +x "$ENVFILE"

echo ">>> [STATION] station_env.sh تم إصلاحه، المفاتيح محفوظة، وUTF-8 مفعّل."
