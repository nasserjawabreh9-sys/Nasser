#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

python - <<'PY'
from pathlib import Path
import re

def apply(path: str, fn):
    p = Path(path)
    if not p.exists():
        print("SKIP (missing):", path)
        return
    txt = p.read_text(encoding="utf-8", errors="ignore")
    new = fn(txt)
    if new != txt:
        p.write_text(new, encoding="utf-8")
        print("PATCHED:", path)
    else:
        print("OK:", path)

# 1) StationConsole.tsx: fix type-only imports + remove unused Rooms/Termux imports
def patch_station_console(txt: str) -> str:
    # Remove unused imports if present
    txt = re.sub(r'^\s*import\s+RoomsPanel\s+from\s+["\'][^"\']+["\'];\s*\n', '', txt, flags=re.M)
    txt = re.sub(r'^\s*import\s+TermuxPanel\s+from\s+["\'][^"\']+["\'];\s*\n', '', txt, flags=re.M)

    # SideBar import: split NavKey as type-only
    txt = re.sub(
        r'import\s+SideBar,\s*\{\s*NavKey\s*\}\s+from\s+([\'"].+SideBar[\'"]);',
        r'import SideBar from \1;\nimport type { NavKey } from \1;',
        txt
    )

    # KeysState: type-only import
    txt = re.sub(
        r'import\s+\{\s*KeysState\s*,\s*loadKeysSafe\s*,\s*saveKeysSafe\s*\}\s+from\s+([\'"].+storage[\'"]);',
        r'import type { KeysState } from \1;\nimport { loadKeysSafe, saveKeysSafe } from \1;',
        txt
    )
    return txt

# 2) Files that import KeysState as value: change to type-only
def patch_keysstate_typeonly(txt: str) -> str:
    # If it imports KeysState with other values -> split
    m = re.search(r'import\s+\{\s*([^}]+)\s*\}\s+from\s+([\'"].+storage[\'"]);', txt)
    if not m:
        return txt
    items = [x.strip() for x in m.group(1).split(",")]
    if "KeysState" not in items:
        return txt
    vals = [x for x in items if x != "KeysState" and x]
    # Replace the whole import line
    old = m.group(0)
    parts = [f'import type {{ KeysState }} from {m.group(2)};']
    if vals:
        parts.append(f'import {{ {", ".join(vals)} }} from {m.group(2)};')
    new = "\n".join(parts)
    return txt.replace(old, new)

# 3) Dashboard ChatItem.role: loosen role typing to string (Termux-safe quick fix)
def patch_dashboard_chatitem(txt: str) -> str:
    # Typical shapes:
    # type ChatItem = { role: "user" | "system"; ... }
    txt2 = re.sub(r'role:\s*("user"\s*\|\s*"system")\s*;', 'role: string;', txt)
    # Also handle interface ChatItem { role: ... }
    txt2 = re.sub(r'(interface\s+ChatItem\s*\{[^}]*?)role:\s*("user"\s*\|\s*"system")\s*;', r'\1role: string;', txt2, flags=re.S)
    return txt2

apply("src/StationConsole.tsx", patch_station_console)
apply("src/components/Dashboard.tsx", lambda t: patch_dashboard_chatitem(patch_keysstate_typeonly(t)))
apply("src/components/Landing.tsx", patch_keysstate_typeonly)
apply("src/components/OpsPanel.tsx", patch_keysstate_typeonly)
apply("src/components/SettingsModal.tsx", patch_keysstate_typeonly)

print("DONE patch_frontend_ts_v2_2")
PY

echo
echo "=== Running TypeScript build ==="
npm run build
