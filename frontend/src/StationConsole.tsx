import { useMemo, useState } from "react";
import SideBar from "./components/SideBar";
import type { NavKey } from "./components/SideBar";
import TopBar from "./components/TopBar";
import Landing from "./components/Landing";
import Dashboard from "./components/Dashboard";
import SettingsModal from "./components/SettingsModal";
import OpsPanel from "./components/OpsPanel";
import AboutPanel from "./components/AboutPanel";
import { jpost } from "./components/api";
import type { KeysState } from "./components/storage";
import { loadKeysSafe, saveKeysSafe } from "./components/storage";

type Strip = { id: string; title: string; desc: string; action: "settings" | "noop" };

export default function StationConsole() {
  const [nav, setNav] = useState<NavKey>("landing");
  const [keys, setKeys] = useState<KeysState>(() => loadKeysSafe());
  const [settingsOpen, setSettingsOpen] = useState(false);
  const [clearSig, setClearSig] = useState(0);
  const [stripDismiss, setStripDismiss] = useState<Record<string, boolean>>({});
  const [statusText, setStatusText] = useState<string>("");

  const strips = useMemo<Strip[]>(() => {
    const s: Strip[] = [];
    if (!keys.openaiKey?.trim()) s.push({ id: "need_openai", title: "OpenAI key missing", desc: "Set OpenAI key to activate AI features.", action: "settings" });
    if (!keys.githubToken?.trim()) s.push({ id: "need_github", title: "GitHub token missing", desc: "Set token to enable Git ops.", action: "settings" });
    if (!keys.renderApiKey?.trim()) s.push({ id: "need_render", title: "Render API key missing", desc: "Set key if you want one-click deploy.", action: "settings" });
    return s;
  }, [keys]);

  function dismiss(id: string) {
    setStripDismiss((x) => ({ ...x, [id]: true }));
  }

  async function pushBackend() {
    setStatusText("Pushing to backend...");
    try {
      const r = await jpost("/keys", { keys });
      setStatusText("Saved to backend: " + (r?.ok ? "OK" : "unknown"));
    } catch (e: any) {
      setStatusText("Backend /keys not available (stub). " + String(e?.message || e));
    }
  }

  return (
    <div className="appRoot">
      <TopBar
        title="Station"
        subtitle="Official Console • Blue Luxury"
        rightHint={`Nav: ${nav.toUpperCase()}`}
        onOpenSettings={() => setSettingsOpen(true)}
        onClearChat={() => setClearSig((n) => n + 1)}
      />

      <div className="mainRow">
        <SideBar active={nav} onNav={setNav} />

        <div className="content">
          <div className="stripStack">
            {strips
              .filter((x) => !stripDismiss[x.id])
              .map((x) => (
                <div className="strip" key={x.id}>
                  <div className="stripLeft">
                    <strong>{x.title}</strong>
                    <small>{x.desc}</small>
                  </div>
                  <div style={{ display: "flex", gap: 8 }}>
                    {x.action === "settings" ? (
                      <button className="btn btnPrimary" onClick={() => setSettingsOpen(true)}>
                        Fix
                      </button>
                    ) : null}
                    <button className="btn" onClick={() => dismiss(x.id)}>
                      Hide
                    </button>
                  </div>
                </div>
              ))}
          </div>

          <div style={{ flex: 1, overflow: "hidden" }}>
            {nav === "landing" ? (
              <Landing
                keys={keys}
                onOpenSettings={() => setSettingsOpen(true)}
                onEnter={() => setNav("dashboard")}
              />
            ) : nav === "dashboard" ? (
              <Dashboard keys={keys} onOpenSettings={() => setSettingsOpen(true)} clearSignal={clearSig} />
            ) : nav === "ops" ? (
              <OpsPanel keys={keys} />
            ) : (
              <AboutPanel />
            )}
          </div>
        </div>
      </div>

      <SettingsModal
        open={settingsOpen}
        keys={keys}
        onChange={setKeys}
        onClose={() => setSettingsOpen(false)}
        onSaveLocal={() => {
          saveKeysSafe(keys);
          setStatusText("Saved locally.");
        }}
        onPushBackend={() => void pushBackend()}
        pushEnabled={Boolean(keys.editModeKey?.trim())}
        statusText={statusText}
      />
    </div>
  );
}
