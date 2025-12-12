import { useEffect, useMemo, useState } from "react";

type Keys = {
  openai_api_key: string;
  github_token: string;
  tts_key: string;
  webhooks_url: string;
  ocr_key: string;
  web_integration_key: string;
  whatsapp_key: string;
  email_smtp: string;
  github_repo: string;
  render_api_key: string;
  edit_mode_key: string;
};

const LS_KEY = "station.uui.keys.v1";

const emptyKeys: Keys = {
  openai_api_key: "",
  github_token: "",
  tts_key: "",
  webhooks_url: "",
  ocr_key: "",
  web_integration_key: "",
  whatsapp_key: "",
  email_smtp: "",
  github_repo: "",
  render_api_key: "",
  edit_mode_key: "1234"
};

export default function Settings() {
  const [keys, setKeys] = useState<Keys>(emptyKeys);
  const [status, setStatus] = useState<string>("");
  const [gitOut, setGitOut] = useState<string>("");

  useEffect(() => {
    const raw = localStorage.getItem(LS_KEY);
    if (raw) {
      try { setKeys({ ...emptyKeys, ...JSON.parse(raw) }); } catch {}
    }
  }, []);

  useEffect(() => {
    localStorage.setItem(LS_KEY, JSON.stringify(keys));
  }, [keys]);

  const fields = useMemo(() => ([
    ["openai_api_key", "OpenAI API Key"],
    ["github_token", "GitHub Token"],
    ["tts_key", "TTS Key"],
    ["webhooks_url", "Webhooks URL"],
    ["ocr_key", "OCR Key"],
    ["web_integration_key", "Web Integration Key"],
    ["whatsapp_key", "WhatsApp Key"],
    ["email_smtp", "Email SMTP (string)"],
    ["github_repo", "GitHub Repo (owner/repo)"],
    ["render_api_key", "Render API Key"],
    ["edit_mode_key", "Edit Mode Key (required for Ops)"]
  ] as const), []);

  async function gitStatus() {
    setStatus("Git status...");
    setGitOut("");
    try {
      const res = await fetch("/api/ops/git/status", {
        headers: { "X-Edit-Key": keys.edit_mode_key || "" }
      });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || String(res.status));
      setGitOut(
        "REMOTE:\n" + (j.remote || "(none)") + "\n\n" +
        "LOG:\n" + (j.log || "(none)") + "\n\n" +
        "CHANGES:\n" + (j.porcelain || "(clean)")
      );
      setStatus("Git status OK.");
    } catch (e: any) {
      setStatus("Git status failed: " + (e?.message || "unknown"));
    }
  }

  async function gitPush() {
    setStatus("Stage + Commit + Push...");
    setGitOut("");
    try {
      const res = await fetch("/api/ops/git/push", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-Edit-Key": keys.edit_mode_key || ""
        },
        body: JSON.stringify({ root_id: 1000, msg: "UI stage/commit/push", strict: "0" })
      });
      const j = await res.json();
      if (!res.ok) throw new Error(j?.error || String(res.status));
      setGitOut(j.out_tail || "(no output)");
      setStatus(j.ok ? "Push OK." : ("Push finished with rc=" + j.rc));
    } catch (e: any) {
      setStatus("Push failed: " + (e?.message || "unknown"));
    }
  }

  return (
    <div style={{ padding: 16, maxWidth: 920, margin: "0 auto" }}>
      <h2>Station Settings</h2>
      <p>Keys are stored in LocalStorage. Ops endpoints require Edit Mode Key.</p>

      <div style={{ display: "grid", gap: 12 }}>
        {fields.map(([k, label]) => (
          <label key={k} style={{ display: "grid", gap: 6 }}>
            <span style={{ fontWeight: 600 }}>{label}</span>
            <input
              value={(keys as any)[k]}
              onChange={(e) => setKeys(prev => ({ ...prev, [k]: e.target.value }))}
              placeholder={label}
              style={{ padding: 10, borderRadius: 8, border: "1px solid #333", background: "#111", color: "#eee" }}
            />
          </label>
        ))}
      </div>

      <div style={{ display: "flex", gap: 10, marginTop: 14, flexWrap: "wrap" }}>
        <button onClick={gitStatus} style={{ padding: "10px 14px", borderRadius: 10, border: "1px solid #444", background: "#1b1b1b", color: "#eee" }}>
          Git Status (Backend)
        </button>
        <button onClick={gitPush} style={{ padding: "10px 14px", borderRadius: 10, border: "1px solid #444", background: "#1b1b1b", color: "#eee" }}>
          Stage + Commit + Push (Backend)
        </button>
        <span style={{ opacity: 0.85, alignSelf: "center" }}>{status}</span>
      </div>

      <pre style={{ marginTop: 14, padding: 12, borderRadius: 10, border: "1px solid #333", background: "#0e0e0e", color: "#ddd", whiteSpace: "pre-wrap" }}>
        {gitOut || "Ops output will appear here."}
      </pre>
    </div>
  );
}
