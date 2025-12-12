#!/data/data/com.termux/files/usr/bin/bash
set -e
p="frontend/src/pages/Settings.tsx"

python - <<'PY'
from pathlib import Path
p = Path("frontend/src/pages/Settings.tsx")
txt = p.read_text(encoding="utf-8")

if "async function saveToBackend" not in txt:
    # if missing entirely, we won't rebuild whole page; just fail loudly
    raise SystemExit("Settings.tsx missing saveToBackend; open file and confirm it's the expected one.")

if "async function loadFromBackend" not in txt:
    insert = r'''
  async function loadFromBackend() {
    setStatus("Loading from backend...");
    try {
      const res = await fetch("/api/config/uui", {
        headers: { "X-Edit-Key": keys.edit_mode_key || "" }
      });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || String(res.status));
      const gotKeys = (j.keys || j?.data?.keys || {});
      setKeys((prev) => ({ ...prev, ...gotKeys }));
      setStatus("Loaded from backend.");
    } catch (e: any) {
      setStatus("Load failed: " + (e?.message || "unknown"));
    }
  }
'''
    # place after saveToBackend block if exists; else after fields memo
    if "async function gitStatus" in txt:
        txt = txt.replace("async function gitStatus()", insert + "\n  async function gitStatus()")
    else:
        txt = txt.replace("const fields = useMemo", insert + "\n  const fields = useMemo")

# ensure button exists
if "Load from Backend" not in txt:
    # insert near buttons row by finding Git Status button
    needle = "Git Status (Backend)"
    if needle in txt:
        txt = txt.replace(
            f">{needle}<",
            f">{needle}<"
        )
    # do nothing (user may already have it)

p.write_text(txt, encoding="utf-8")
print("OK: loadFromBackend ensured in Settings.tsx")
PY
