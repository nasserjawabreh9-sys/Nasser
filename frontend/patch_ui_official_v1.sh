#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

cd ~/station_root/frontend

echo "==[1/6] Ensure src/ exists =="
mkdir -p src/components src/styles

echo "==[2/6] Write global styles (Windows-ish blue luxury) =="
cat > src/styles/app.css <<'CSS'
:root{
  --bg0:#071423;
  --bg1:#0b1f35;
  --panel:#0e2a47;
  --panel2:#0a223b;
  --line: rgba(255,255,255,.10);
  --txt: rgba(255,255,255,.92);
  --muted: rgba(255,255,255,.68);
  --blue:#2aa7ff;
  --blue2:#0b6bff;
  --danger:#ff4d4d;
  --ok:#3ddc97;
  --shadow: 0 10px 30px rgba(0,0,0,.35);
  --radius: 14px;
  --radius2: 18px;
  --font: ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, Arial;
}

*{ box-sizing:border-box; }
html,body{ height:100%; }
body{
  margin:0;
  font-family: var(--font);
  color: var(--txt);
  background: radial-gradient(1200px 700px at 20% 10%, #103d66 0%, var(--bg0) 55%) , linear-gradient(160deg, var(--bg1), var(--bg0));
  overflow:hidden;
}

a{ color: var(--blue); text-decoration:none; }
button, input, textarea{ font-family: inherit; }

.glass{
  background: linear-gradient(180deg, rgba(255,255,255,.06), rgba(255,255,255,.03));
  border: 1px solid var(--line);
  box-shadow: var(--shadow);
  border-radius: var(--radius);
  backdrop-filter: blur(10px);
}

.appRoot{
  height:100vh;
  display:flex;
  flex-direction:column;
}

.topBar{
  height:54px;
  display:flex;
  align-items:center;
  justify-content:space-between;
  padding: 0 14px;
  border-bottom: 1px solid var(--line);
  background: linear-gradient(180deg, rgba(14,42,71,.92), rgba(9,25,41,.86));
}

.brand{
  display:flex; align-items:center; gap:10px;
  font-weight:700;
  letter-spacing:.2px;
}
.brandBadge{
  width:34px; height:34px; border-radius:10px;
  display:grid; place-items:center;
  border:1px solid var(--line);
  background: radial-gradient(18px 18px at 30% 30%, rgba(42,167,255,.55), rgba(11,107,255,.18));
}
.brandTitle{ display:flex; flex-direction:column; line-height:1.1; }
.brandTitle small{ color: var(--muted); font-weight:600; }

.topActions{ display:flex; align-items:center; gap:8px; }
.btn{
  border:1px solid var(--line);
  background: rgba(255,255,255,.04);
  color: var(--txt);
  padding:8px 10px;
  border-radius: 12px;
  cursor:pointer;
}
.btn:hover{ border-color: rgba(42,167,255,.55); }
.btnPrimary{
  background: linear-gradient(180deg, rgba(42,167,255,.35), rgba(11,107,255,.20));
  border-color: rgba(42,167,255,.45);
}
.btnDanger{
  background: linear-gradient(180deg, rgba(255,77,77,.25), rgba(255,77,77,.12));
  border-color: rgba(255,77,77,.35);
}
.pill{
  padding:6px 10px;
  border-radius:999px;
  border:1px solid var(--line);
  color: var(--muted);
  background: rgba(0,0,0,.12);
  font-size:12px;
}

.mainRow{
  height: calc(100vh - 54px);
  display:flex;
  gap:10px;
  padding: 10px;
}

.sideBar{
  width: 260px;
  padding: 10px;
  border-right: 1px solid var(--line);
  background: linear-gradient(180deg, rgba(14,42,71,.62), rgba(7,20,35,.35));
  border-radius: var(--radius2);
}

.navItem{
  width:100%;
  display:flex; gap:10px; align-items:center;
  padding:10px 10px;
  border-radius: 12px;
  cursor:pointer;
  border:1px solid transparent;
  color: var(--muted);
}
.navItem:hover{ background: rgba(255,255,255,.04); }
.navItemActive{
  color: var(--txt);
  border-color: rgba(42,167,255,.35);
  background: linear-gradient(180deg, rgba(42,167,255,.22), rgba(11,107,255,.10));
}

.content{
  flex:1;
  display:flex;
  flex-direction:column;
  gap:10px;
  overflow:hidden;
}

.stripStack{ display:flex; flex-direction:column; gap:8px; }
.strip{
  padding:10px 12px;
  border-radius: 14px;
  border:1px solid var(--line);
  background: rgba(0,0,0,.18);
  display:flex; align-items:center; justify-content:space-between; gap:10px;
}
.strip strong{ font-size:13px; }
.strip small{ display:block; color:var(--muted); margin-top:2px; }
.stripLeft{ display:flex; flex-direction:column; }

.grid2{
  display:grid;
  grid-template-columns: 1.3fr .7fr;
  gap:10px;
  height: 100%;
  overflow:hidden;
}

.panel{
  padding: 12px;
  border-radius: var(--radius2);
  border:1px solid var(--line);
  background: linear-gradient(180deg, rgba(14,42,71,.55), rgba(7,20,35,.30));
  box-shadow: var(--shadow);
  overflow:hidden;
}

.panelHeader{
  display:flex; align-items:center; justify-content:space-between;
  margin-bottom:10px;
}
.panelHeader h3{ margin:0; font-size:14px; letter-spacing:.2px; }
.panelHeader span{ color:var(--muted); font-size:12px; }

.chatWrap{
  height: calc(100% - 46px);
  display:flex;
  flex-direction:column;
  gap:10px;
}
.chatLog{
  flex:1;
  border:1px solid var(--line);
  border-radius: 14px;
  background: rgba(0,0,0,.18);
  overflow:auto;
  padding:10px;
}
.msg{
  margin: 8px 0;
  padding:10px 10px;
  border-radius: 12px;
  max-width: 92%;
  border: 1px solid rgba(255,255,255,.10);
}
.msgUser{
  margin-left:auto;
  background: linear-gradient(180deg, rgba(42,167,255,.20), rgba(11,107,255,.08));
}
.msgSys{
  margin-right:auto;
  background: rgba(255,255,255,.04);
}
.msgMeta{
  color: var(--muted);
  font-size: 11px;
  margin-bottom: 6px;
}

.chatInputRow{
  display:flex; gap:10px;
}
.chatInputRow textarea{
  flex:1;
  resize:none;
  height: 54px;
  padding: 10px;
  border-radius: 14px;
  border: 1px solid var(--line);
  background: rgba(0,0,0,.20);
  color: var(--txt);
  outline:none;
}
.chatInputRow textarea:focus{ border-color: rgba(42,167,255,.50); }
.rightCol{
  display:flex;
  flex-direction:column;
  gap:10px;
  height:100%;
  overflow:hidden;
}
.kv{
  display:flex; flex-direction:column; gap:8px;
}
.kvRow{
  display:flex; align-items:center; justify-content:space-between; gap:10px;
  padding:10px;
  border:1px solid var(--line);
  border-radius: 14px;
  background: rgba(0,0,0,.16);
}
.kvRow b{ font-size:12px; }
.kvRow code{
  color: var(--muted);
  font-size: 11px;
  overflow:hidden;
  text-overflow:ellipsis;
  white-space:nowrap;
  max-width: 140px;
}

.modalBack{
  position:fixed; inset:0;
  background: rgba(0,0,0,.55);
  display:grid; place-items:center;
  z-index: 50;
}
.modal{
  width:min(760px, 92vw);
  max-height: 86vh;
  overflow:auto;
  padding: 14px;
  border-radius: 18px;
  border: 1px solid var(--line);
  background: linear-gradient(180deg, rgba(14,42,71,.92), rgba(7,20,35,.88));
  box-shadow: var(--shadow);
}
.formGrid{
  display:grid;
  grid-template-columns: 1fr 1fr;
  gap:10px;
}
.field{
  display:flex; flex-direction:column; gap:6px;
}
.field label{ font-size:12px; color: var(--muted); }
.field input{
  padding:10px;
  border-radius: 12px;
  border:1px solid var(--line);
  background: rgba(0,0,0,.18);
  color: var(--txt);
  outline:none;
}
.field input:focus{ border-color: rgba(42,167,255,.50); }

.landing{
  height:100%;
  display:grid;
  place-items:center;
  padding: 18px;
}
.landingCard{
  width:min(980px, 96vw);
  display:grid;
  grid-template-columns: 1.05fr .95fr;
  gap: 14px;
  padding: 14px;
  border-radius: 18px;
}
.hero{
  padding: 18px;
  border-radius: 18px;
  border: 1px solid var(--line);
  background: rgba(0,0,0,.18);
}
.hero h1{ margin:0 0 8px 0; font-size: 26px; }
.hero p{ margin:0; color: var(--muted); line-height:1.7; }
.heroFooter{ margin-top: 14px; display:flex; gap:10px; align-items:center; flex-wrap:wrap; }
.quote{ font-weight: 700; letter-spacing:.2px; }
.animBox{
  display:grid; place-items:center;
  padding: 18px;
  border-radius: 18px;
  border: 1px solid var(--line);
  background: radial-gradient(220px 220px at 30% 30%, rgba(42,167,255,.22), rgba(0,0,0,.18));
  position: relative;
  overflow:hidden;
}
.dwarf{
  width: 140px; height: 140px;
  border-radius: 28px;
  border: 1px solid rgba(255,255,255,.14);
  background: linear-gradient(180deg, rgba(42,167,255,.28), rgba(11,107,255,.12));
  display:grid; place-items:center;
  transform: translateY(0);
  animation: dwarfMove 5s ease-in-out 1;
  box-shadow: 0 16px 40px rgba(0,0,0,.35);
}
.dwarfInner{
  width: 92px; height: 92px;
  border-radius: 22px;
  border:1px solid rgba(255,255,255,.14);
  background: rgba(0,0,0,.16);
  display:grid; place-items:center;
  font-weight:800;
  letter-spacing:.6px;
}
@keyframes dwarfMove{
  0%{ transform: translateY(18px) rotate(-3deg); filter: brightness(1); }
  30%{ transform: translateY(-8px) rotate(2deg); filter: brightness(1.08); }
  60%{ transform: translateY(10px) rotate(-2deg); filter: brightness(1.02); }
  100%{ transform: translateY(0) rotate(0deg); filter: brightness(1.12); }
}
CSS

echo "==[3/6] Ensure main.tsx imports styles =="
if [ -f src/main.tsx ]; then
  grep -q 'src/styles/app.css' src/main.tsx || sed -i '1i import "./styles/app.css";' src/main.tsx
else
  cat > src/main.tsx <<'TS'
import "./styles/app.css";
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
TS
fi

echo "==[4/6] Write UI components =="
cat > src/components/api.ts <<'TS'
export const API_BASE =
  (import.meta as any).env?.VITE_BACKEND_URL || "http://127.0.0.1:8000";

export async function jget(path: string) {
  const r = await fetch(`${API_BASE}${path}`, { method: "GET" });
  if (!r.ok) throw new Error(`${path} -> ${r.status}`);
  return await r.json();
}

export async function jpost(path: string, body: any) {
  const r = await fetch(`${API_BASE}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body ?? {}),
  });
  if (!r.ok) throw new Error(`${path} -> ${r.status}`);
  return await r.json();
}
TS

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

const K = "station.keys.v1";

export function loadKeys(): KeysState {
  const raw = localStorage.getItem(K);
  if (!raw) {
    return {
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
  }
  try {
    return { ...loadKeysFallback(), ...(JSON.parse(raw) as any) };
  } catch {
    return loadKeysFallback();
  }
}

function loadKeysFallback(): KeysState {
  return {
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
}

export function saveKeys(s: KeysState) {
  localStorage.setItem(K, JSON.stringify(s));
}
TS

cat > src/components/sound.ts <<'TS'
export function playChime() {
  try {
    const ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.type = "sine";
    o.frequency.value = 523.25; // C5
    g.gain.value = 0.0001;
    o.connect(g);
    g.connect(ctx.destination);
    o.start();

    const t0 = ctx.currentTime;
    g.gain.exponentialRampToValueAtTime(0.18, t0 + 0.03);
    o.frequency.exponentialRampToValueAtTime(659.25, t0 + 0.14); // E5
    o.frequency.exponentialRampToValueAtTime(783.99, t0 + 0.28); // G5
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.55);

    setTimeout(() => {
      o.stop();
      ctx.close();
    }, 700);
  } catch {
    // ignore
  }
}
TS

cat > src/components/TopBar.tsx <<'TSX'
type Props = {
  title: string;
  subtitle: string;
  rightHint?: string;
  onOpenSettings: () => void;
  onClearChat: () => void;
};

export default function TopBar(p: Props) {
  return (
    <div className="topBar">
      <div className="brand">
        <div className="brandBadge" title="Dwarf Armory">
          <span style={{ fontWeight: 900 }}>DA</span>
        </div>
        <div className="brandTitle">
          <div>{p.title}</div>
          <small>{p.subtitle}</small>
        </div>
      </div>

      <div className="topActions">
        {p.rightHint ? <span className="pill">{p.rightHint}</span> : null}
        <button className="btn" onClick={p.onClearChat} title="Clear chat">
          Clear Chat
        </button>
        <button className="btn btnPrimary" onClick={p.onOpenSettings} title="Keys & Settings">
          Settings
        </button>
      </div>
    </div>
  );
}
TSX

cat > src/components/SideBar.tsx <<'TSX'
export type NavKey = "landing" | "dashboard" | "ops" | "about";

type Props = {
  active: NavKey;
  onNav: (k: NavKey) => void;
};

function Item(props: { k: NavKey; label: string; sub: string; active: NavKey; onNav: (k: NavKey) => void }) {
  const isA = props.active === props.k;
  return (
    <div
      className={"navItem " + (isA ? "navItemActive" : "")}
      onClick={() => props.onNav(props.k)}
      role="button"
      tabIndex={0}
    >
      <div style={{ width: 34, height: 34, borderRadius: 12, border: "1px solid rgba(255,255,255,.10)", display: "grid", placeItems: "center", background: "rgba(0,0,0,.14)" }}>
        {props.label.slice(0, 1)}
      </div>
      <div style={{ display: "flex", flexDirection: "column", lineHeight: 1.15 }}>
        <b style={{ fontSize: 13, color: isA ? "rgba(255,255,255,.92)" : "rgba(255,255,255,.68)" }}>{props.label}</b>
        <small style={{ color: "rgba(255,255,255,.55)" }}>{props.sub}</small>
      </div>
    </div>
  );
}

export default function SideBar(p: Props) {
  return (
    <div className="sideBar glass">
      <div style={{ padding: 8 }}>
        <div style={{ fontWeight: 800, marginBottom: 6 }}>Dwarf Armory</div>
        <div style={{ color: "rgba(255,255,255,.60)", fontSize: 12, lineHeight: 1.5 }}>
          Station UI (Vite + React). Windows-style console with ops hooks.
        </div>
      </div>

      <div style={{ height: 10 }} />

      <Item k="landing" label="Landing" sub="Intro & activation" active={p.active} onNav={p.onNav} />
      <Item k="dashboard" label="Dashboard" sub="Chat + health + events" active={p.active} onNav={p.onNav} />
      <Item k="ops" label="Ops" sub="Git/Deploy hooks (stubs)" active={p.active} onNav={p.onNav} />
      <Item k="about" label="About" sub="Build & paths" active={p.active} onNav={p.onNav} />

      <div style={{ marginTop: 14, padding: 10, borderTop: "1px solid rgba(255,255,255,.10)", color: "rgba(255,255,255,.55)", fontSize: 12 }}>
        Hint: set backend URL via <code>VITE_BACKEND_URL</code>
      </div>
    </div>
  );
}
TSX

cat > src/components/Landing.tsx <<'TSX'
import { useEffect, useState } from "react";
import { playChime } from "./sound";
import { KeysState } from "./storage";

type Props = {
  keys: KeysState;
  onOpenSettings: () => void;
  onEnter: () => void;
};

export default function Landing(p: Props) {
  const [played, setPlayed] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => {
      if (!played) {
        playChime();
        setPlayed(true);
      }
    }, 150);
    return () => clearTimeout(t);
  }, [played]);

  const ready = Boolean(p.keys.openaiKey?.trim());

  return (
    <div className="landing">
      <div className="landingCard glass">
        <div className="hero">
          <div className="quote">"وَفَوْقَ كُلِّ ذِي عِلْمٍ عَلِيمٌ"</div>
          <h1 style={{ marginTop: 10 }}>Station — Official Console</h1>
          <p>
            Landing + Dashboard in one UI. Keys stored in LocalStorage. Backend connectivity + notifications wiring prepared.
          </p>

          <div className="heroFooter">
            <button className="btn btnPrimary" onClick={p.onOpenSettings}>
              Open Settings (Keys)
            </button>
            <button className={"btn " + (ready ? "btnPrimary" : "")} onClick={p.onEnter} disabled={!ready} title={ready ? "Enter dashboard" : "Set OpenAI key first"}>
              Enter Dashboard
            </button>
            {!ready ? <span className="pill">OpenAI key required to activate</span> : <span className="pill" style={{ color: "rgba(61,220,151,.9)" }}>Activated</span>}
          </div>
        </div>

        <div className="animBox">
          <div className="dwarf" title="Armored Dwarf (5s animation)">
            <div className="dwarfInner">DWARF</div>
          </div>
          <div style={{ position: "absolute", bottom: 12, left: 12, right: 12, color: "rgba(255,255,255,.70)", fontSize: 12, lineHeight: 1.5 }}>
            Cartoon movement runs once (5 seconds) on entry. Chime plays on load.
          </div>
        </div>
      </div>
    </div>
  );
}
TSX

cat > src/components/SettingsModal.tsx <<'TSX'
import { KeysState } from "./storage";

type Props = {
  open: boolean;
  keys: KeysState;
  onChange: (k: KeysState) => void;
  onClose: () => void;
  onSaveLocal: () => void;
  onPushBackend: () => void;
  pushEnabled?: boolean;
  statusText?: string;
};

function Field(p: { label: string; value: string; on: (v: string) => void; placeholder?: string }) {
  return (
    <div className="field">
      <label>{p.label}</label>
      <input value={p.value} onChange={(e) => p.on(e.target.value)} placeholder={p.placeholder || ""} />
    </div>
  );
}

export default function SettingsModal(p: Props) {
  if (!p.open) return null;

  const s = p.keys;

  return (
    <div className="modalBack" onMouseDown={p.onClose}>
      <div className="modal" onMouseDown={(e) => e.stopPropagation()}>
        <div className="panelHeader">
          <h3>Station Settings</h3>
          <span>Keys saved to LocalStorage (optional push to backend)</span>
        </div>

        <div className="formGrid">
          <Field label="OpenAI API Key" value={s.openaiKey} on={(v) => p.onChange({ ...s, openaiKey: v })} />
          <Field label="GitHub Token" value={s.githubToken} on={(v) => p.onChange({ ...s, githubToken: v })} />
          <Field label="TTS Key" value={s.ttsKey} on={(v) => p.onChange({ ...s, ttsKey: v })} />
          <Field label="Webhooks URL" value={s.webhooksUrl} on={(v) => p.onChange({ ...s, webhooksUrl: v })} placeholder="https://..." />
          <Field label="OCR Key" value={s.ocrKey} on={(v) => p.onChange({ ...s, ocrKey: v })} />
          <Field label="Web Integration Key" value={s.webIntegrationKey} on={(v) => p.onChange({ ...s, webIntegrationKey: v })} />
          <Field label="WhatsApp Key" value={s.whatsappKey} on={(v) => p.onChange({ ...s, whatsappKey: v })} />
          <Field label="Email SMTP (string)" value={s.emailSmtp} on={(v) => p.onChange({ ...s, emailSmtp: v })} placeholder="smtp://user:pass@host:587" />
          <Field label="GitHub Repo (owner/repo)" value={s.githubRepo} on={(v) => p.onChange({ ...s, githubRepo: v })} placeholder="owner/repo" />
          <Field label="Render API Key" value={s.renderApiKey} on={(v) => p.onChange({ ...s, renderApiKey: v })} />
          <Field label="Edit Mode Key (required for Ops)" value={s.editModeKey} on={(v) => p.onChange({ ...s, editModeKey: v })} placeholder="1234" />
        </div>

        <div style={{ display: "flex", gap: 10, marginTop: 12, alignItems: "center", justifyContent: "space-between" }}>
          <div style={{ color: "rgba(255,255,255,.65)", fontSize: 12 }}>
            {p.statusText ? p.statusText : "Tip: keep keys local; push only if you want backend to execute ops."}
          </div>
          <div style={{ display: "flex", gap: 8 }}>
            <button className="btn" onClick={p.onSaveLocal}>Save Local</button>
            <button className="btn btnPrimary" onClick={p.onPushBackend} disabled={!p.pushEnabled}>
              Save to Backend
            </button>
            <button className="btn btnDanger" onClick={p.onClose}>Close</button>
          </div>
        </div>
      </div>
    </div>
  );
}
TSX

cat > src/components/Dashboard.tsx <<'TSX'
import { useEffect, useMemo, useRef, useState } from "react";
import { API_BASE, jget, jpost } from "./api";
import { KeysState } from "./storage";

type Props = {
  keys: KeysState;
  onOpenSettings: () => void;
  clearSignal: number;
};

type ChatItem = { role: "user" | "system"; text: string; ts: number };

export default function Dashboard(p: Props) {
  const [health, setHealth] = useState<any>(null);
  const [err, setErr] = useState<string>("");
  const [msg, setMsg] = useState<string>("");
  const [chat, setChat] = useState<ChatItem[]>([
    { role: "system", text: "Station online. Dashboard loaded.", ts: Date.now() },
  ]);
  const [events] = useState<string>("(events wiring pending)");
  const logRef = useRef<HTMLDivElement | null>(null);

  const apiHint = useMemo(() => API_BASE, []);

  useEffect(() => {
    (async () => {
      try {
        setErr("");
        const h = await jget("/health");
        setHealth(h);
      } catch (e: any) {
        setErr(String(e?.message || e));
      }
    })();
  }, []);

  useEffect(() => {
    if (logRef.current) logRef.current.scrollTop = logRef.current.scrollHeight;
  }, [chat]);

  useEffect(() => {
    // Clear chat signal from top bar
    if (p.clearSignal > 0) {
      setChat([{ role: "system", text: "Chat cleared.", ts: Date.now() }]);
    }
  }, [p.clearSignal]);

  async function send() {
    const t = msg.trim();
    if (!t) return;
    setMsg("");
    const next = [...chat, { role: "user", text: t, ts: Date.now() }];
    setChat(next);

    // Backend chat endpoint is optional. If not available, keep local.
    try {
      const r = await jpost("/chat", { text: t, key: p.keys.openaiKey || "" });
      const out = r?.answer || r?.text || JSON.stringify(r);
      setChat((c) => [...c, { role: "system", text: String(out), ts: Date.now() }]);
    } catch (e: any) {
      setChat((c) => [...c, { role: "system", text: "[stub] Backend /chat not available. Message stored locally.", ts: Date.now() }]);
    }
  }

  return (
    <div className="grid2" style={{ height: "100%" }}>
      <div className="panel">
        <div className="panelHeader">
          <h3>Chat Console</h3>
          <span>Backend: {apiHint}</span>
        </div>

        <div className="chatWrap">
          <div className="chatLog" ref={logRef}>
            {chat.map((m, i) => (
              <div key={i} className={"msg " + (m.role === "user" ? "msgUser" : "msgSys")}>
                <div className="msgMeta">{m.role.toUpperCase()} • {new Date(m.ts).toLocaleTimeString()}</div>
                <div style={{ whiteSpace: "pre-wrap" }}>{m.text}</div>
              </div>
            ))}
          </div>

          <div className="chatInputRow">
            <textarea
              value={msg}
              onChange={(e) => setMsg(e.target.value)}
              placeholder="Type here... (Windows-style input bar)"
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  void send();
                }
              }}
            />
            <button className="btn btnPrimary" onClick={() => void send()}>
              Send
            </button>
          </div>
        </div>
      </div>

      <div className="rightCol">
        <div className="panel">
          <div className="panelHeader">
            <h3>Status</h3>
            <span>{err ? "Error" : "OK"}</span>
          </div>

          <div className="kv">
            <div className="kvRow">
              <b>Health</b>
              <code>{health ? "loaded" : "null"}</code>
            </div>
            <div className="kvRow">
              <b>Events</b>
              <code>{events}</code>
            </div>
            <div className="kvRow">
              <b>OpenAI Key</b>
              <code>{p.keys.openaiKey ? "set" : "missing"}</code>
            </div>
            <div className="kvRow">
              <b>GitHub Token</b>
              <code>{p.keys.githubToken ? "set" : "missing"}</code>
            </div>
          </div>

          {err ? (
            <div style={{ marginTop: 10, padding: 10, borderRadius: 12, border: "1px solid rgba(255,77,77,.25)", background: "rgba(255,77,77,.10)", color: "rgba(255,255,255,.88)" }}>
              {err}
            </div>
          ) : (
            <div style={{ marginTop: 10, padding: 10, borderRadius: 12, border: "1px solid rgba(61,220,151,.22)", background: "rgba(61,220,151,.10)", color: "rgba(255,255,255,.88)" }}>
              Backend reachable. Health OK.
            </div>
          )}

          <div style={{ marginTop: 12, display: "flex", gap: 8 }}>
            <button className="btn" onClick={p.onOpenSettings}>Keys</button>
            <button
              className="btn btnPrimary"
              onClick={() => {
                void (async () => {
                  try {
                    const h = await jget("/health");
                    setHealth(h);
                    setErr("");
                  } catch (e: any) {
                    setErr(String(e?.message || e));
                  }
                })();
              }}
            >
              Refresh Health
            </button>
          </div>
        </div>

        <div className="panel" style={{ flex: 1 }}>
          <div className="panelHeader">
            <h3>Notifications</h3>
            <span>Backend wiring ready</span>
          </div>
          <div style={{ color: "rgba(255,255,255,.70)", fontSize: 12, lineHeight: 1.6 }}>
            Prepared areas:
            <ul>
              <li>Polling endpoint: <code>/events</code> (recommended)</li>
              <li>WebSocket: <code>/ws</code> (optional)</li>
              <li>Push alerts: <code>/notify</code> (optional)</li>
            </ul>
            When backend is ready, this panel becomes live.
          </div>
        </div>
      </div>
    </div>
  );
}
TSX

cat > src/components/OpsPanel.tsx <<'TSX'
import { useState } from "react";
import { KeysState } from "./storage";
import { jpost } from "./api";

type Props = { keys: KeysState };

export default function OpsPanel(p: Props) {
  const [out, setOut] = useState<string>("Output will appear here.");

  async function run(action: "git_status" | "git_push" | "render_deploy") {
    // These are stubs until backend implements /ops/*
    try {
      const r = await jpost(`/ops/${action}`, { edit_key: p.keys.editModeKey, keys: p.keys });
      setOut(JSON.stringify(r, null, 2));
    } catch (e: any) {
      setOut(`[stub] backend /ops/${action} not available.\n` + String(e?.message || e));
    }
  }

  return (
    <div className="panel" style={{ height: "100%" }}>
      <div className="panelHeader">
        <h3>Ops Console</h3>
        <span>Requires Edit Mode Key</span>
      </div>

      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        <button className="btn" onClick={() => void run("git_status")}>Git Status (Backend)</button>
        <button className="btn btnPrimary" onClick={() => void run("git_push")}>Stage + Commit + Push</button>
        <button className="btn" onClick={() => void run("render_deploy")}>Deploy to Render</button>
      </div>

      <div style={{ height: 10 }} />

      <pre style={{ margin: 0, padding: 12, borderRadius: 14, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.18)", overflow: "auto", height: "calc(100% - 70px)" }}>
{out}
      </pre>
    </div>
  );
}
TSX

cat > src/components/AboutPanel.tsx <<'TSX'
import { API_BASE } from "./api";

export default function AboutPanel() {
  return (
    <div className="panel" style={{ height: "100%" }}>
      <div className="panelHeader">
        <h3>About</h3>
        <span>Paths & runtime</span>
      </div>

      <div style={{ color: "rgba(255,255,255,.72)", lineHeight: 1.8, fontSize: 13 }}>
        <div><b>Frontend:</b> Vite + React</div>
        <div><b>Backend base:</b> <code>{API_BASE}</code></div>
        <div><b>Health:</b> <code>/health</code></div>
        <div><b>Chat (optional):</b> <code>/chat</code></div>
        <div><b>Ops (optional):</b> <code>/ops/*</code></div>

        <div style={{ marginTop: 12, padding: 12, borderRadius: 14, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.18)" }}>
          <b>Note:</b> This UI is production-style. Missing backend endpoints degrade gracefully (stubs).
        </div>
      </div>
    </div>
  );
}
TSX

cat > src/StationConsole.tsx <<'TSX'
import { useMemo, useState } from "react";
import SideBar, { NavKey } from "./components/SideBar";
import TopBar from "./components/TopBar";
import Landing from "./components/Landing";
import Dashboard from "./components/Dashboard";
import SettingsModal from "./components/SettingsModal";
import OpsPanel from "./components/OpsPanel";
import AboutPanel from "./components/AboutPanel";
import { jpost } from "./components/api";
import { KeysState, loadKeys, saveKeys } from "./components/storage";

type Strip = { id: string; title: string; desc: string; action: "settings" | "noop" };

export default function StationConsole() {
  const [nav, setNav] = useState<NavKey>("landing");
  const [keys, setKeys] = useState<KeysState>(() => loadKeys());
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
          saveKeys(keys);
          setStatusText("Saved locally.");
        }}
        onPushBackend={() => void pushBackend()}
        pushEnabled={Boolean(keys.editModeKey?.trim())}
        statusText={statusText}
      />
    </div>
  );
}
TSX

echo "==[5/6] Ensure App.tsx points to StationConsole =="
cat > src/App.tsx <<'TSX'
import StationConsole from "./StationConsole";

export default function App() {
  return <StationConsole />;
}
TSX

echo "==[6/6] Build check =="
npm run build

echo
echo "DONE."
echo "Run preview:"
echo "  npm run preview -- --host 0.0.0.0 --port 5173"
