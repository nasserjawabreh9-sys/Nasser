#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
cd ~/station_root/frontend

echo "== Patch: Safe Keys + Ops Guards =="

# 1) Safe storage loader (defaults)
cat > src/components/storage.ts <<'TS'
export type KeysState = {
  openaiKey: string;
  githubToken: string;
  ttsKey: string;
  webhooksUrl: string;
  ocrKey: string;
  webIntegrationKey: string;
  whatsappKey: string;
  emailSmtp: string;
  githubRepo: string;
  renderApiKey: string;
  editModeKey: string;
};

export const DEFAULT_KEYS: KeysState = {
  openaiKey: "",
  githubToken: "",
  ttsKey: "",
  webhooksUrl: "",
  ocrKey: "",
  webIntegrationKey: "",
  whatsappKey: "",
  emailSmtp: "",
  githubRepo: "",
  renderApiKey: "",
  editModeKey: "1234",
};

const K = "station.keys.v1";

export function loadKeysSafe(): KeysState {
  try {
    if (typeof window === "undefined") return { ...DEFAULT_KEYS };
    const raw = window.localStorage.getItem(K);
    if (!raw) return { ...DEFAULT_KEYS };
    return { ...DEFAULT_KEYS, ...(JSON.parse(raw) as Partial<KeysState>) };
  } catch {
    return { ...DEFAULT_KEYS };
  }
}

export function saveKeysSafe(s: KeysState) {
  try {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(K, JSON.stringify({ ...DEFAULT_KEYS, ...s }));
  } catch {}
}
TS

# 2) Replace any direct loadKeys usage with loadKeysSafe
# (safe no-op if not found)
sed -i 's/loadKeys()/loadKeysSafe()/g' src/StationConsole.tsx || true
sed -i 's/import { KeysState, loadKeys, saveKeys }/import { KeysState, loadKeysSafe, saveKeysSafe }/g' src/StationConsole.tsx || true
sed -i 's/saveKeys(/saveKeysSafe(/g' src/StationConsole.tsx || true

# Ensure initialization uses the safe loader
sed -i 's/useState<KeysState>(() => .*loadKeys.*)/useState<KeysState>(() => loadKeysSafe())/g' src/StationConsole.tsx || true

# 3) Guard Ops: never act without repo+token+edit key
cat > src/components/OpsPanel.tsx <<'TSX'
import { useState } from "react";
import { KeysState } from "./storage";
import { jpost } from "./api";

type Props = { keys: KeysState };

export default function OpsPanel(p: Props) {
  const [out, setOut] = useState<string>("Output will appear here.");

  function guard(): string | null {
    if (!p.keys.editModeKey?.trim()) return "Edit Mode Key missing";
    if (!p.keys.githubToken?.trim()) return "GitHub token missing";
    if (!p.keys.githubRepo?.trim()) return "GitHub repo missing (owner/repo)";
    return null;
  }

  async function run(action: "git_status" | "git_push" | "render_deploy") {
    const g = guard();
    if (g) {
      setOut("Blocked by guard: " + g);
      return;
    }
    try {
      const r = await jpost(`/ops/${action}`, {
        edit_key: p.keys.editModeKey,
        keys: p.keys,
      });
      setOut(JSON.stringify(r, null, 2));
    } catch (e: any) {
      setOut("[stub] backend endpoint not available.\n" + String(e?.message || e));
    }
  }

  return (
    <div className="panel" style={{ height: "100%" }}>
      <div className="panelHeader">
        <h3>Ops Console</h3>
        <span>Guards enabled</span>
      </div>

      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        <button className="btn" onClick={() => void run("git_status")}>Git Status</button>
        <button className="btn btnPrimary" onClick={() => void run("git_push")}>Stage + Commit + Push</button>
        <button className="btn" onClick={() => void run("render_deploy")}>Deploy to Render</button>
      </div>

      <pre style={{ marginTop: 10, padding: 12, borderRadius: 14, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.18)", overflow: "auto", height: "calc(100% - 70px)" }}>
{out}
      </pre>
    </div>
  );
}
TSX

# 4) Ensure StationConsole imports the safe APIs
sed -i 's/import { KeysState, loadKeysSafe, saveKeysSafe }/import { KeysState, loadKeysSafe, saveKeysSafe }/g' src/StationConsole.tsx || true

# 5) Build check
npm run build

echo "== Patch applied successfully =="
