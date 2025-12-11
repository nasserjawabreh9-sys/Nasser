#!/data/data/com.termux/files/usr/bin/bash
set -e

echo ">>> [UNIFY] Loading existing env (if any)..."
[ -f station_env.sh ] && source station_env.sh || true

echo ">>> [UNIFY] Detecting key..."
# نأخذ أي مفتاح موجود
KEY_VALUE="${STATION_OPENAI_API_KEY:-$OPENAI_API_KEY}"

if [ -z "$KEY_VALUE" ]; then
  echo "!!! لا يوجد مفتاح محفوظ — أدخل المفتاح الآن:"
  read -r KEY_VALUE
fi

echo ">>> [UNIFY] Writing clean station_env.sh ..."
cat > station_env.sh << EOF2
#!/data/data/com.termux/files/usr/bin/bash

export OPENAI_API_KEY="$KEY_VALUE"
export STATION_OPENAI_API_KEY="$KEY_VALUE"
export GITHUB_TOKEN="$GITHUB_TOKEN"

echo "[station_env] Unified keys loaded."
EOF2

chmod +x station_env.sh
echo ">>> [UNIFY] Done. المفتاح موحد الآن."
echo ">>> افتح جلسة جديدة أو اكتب: source station_env.sh "
