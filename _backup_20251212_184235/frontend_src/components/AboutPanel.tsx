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
