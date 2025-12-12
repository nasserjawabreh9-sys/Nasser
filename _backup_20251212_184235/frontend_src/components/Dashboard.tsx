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
