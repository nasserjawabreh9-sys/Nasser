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
