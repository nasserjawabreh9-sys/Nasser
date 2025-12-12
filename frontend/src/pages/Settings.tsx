import { useEffect, useState } from "react";
import { apiGet, apiPost } from "../lib/api";

type Keys = Record<string, string>;

export default function Settings() {
  const [keys, setKeys] = useState<Keys>({
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
  });
  const [msg, setMsg] = useState<string>("");

  async function load() {
    setMsg("Loading...");
    const j = await apiGet("/api/config/uui");
    setKeys(j?.keys || keys);
    setMsg("Loaded");
  }

  async function save() {
    setMsg("Saving...");
    await apiPost("/api/config/uui", { keys }, keys.edit_mode_key);
    setMsg("Saved");
  }

  useEffect(() => { load().catch(() => setMsg("Load failed")); }, []);

  return (
    <div style={{ padding: 20, maxWidth: 900 }}>
      <h2>Station Settings</h2>
      <p style={{ opacity: 0.8 }}>
        Keys are stored in LocalStorage (UI) + can be pushed to backend. Ops endpoints require Edit Mode Key.
      </p>

      <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
        {Object.keys(keys).map((k) => (
          <label key={k} style={{ display: "flex", flexDirection: "column", gap: 6 }}>
            <span>{k}</span>
            <input
              value={keys[k] ?? ""}
              onChange={(e) => setKeys({ ...keys, [k]: e.target.value })}
              style={{ padding: 10 }}
            />
          </label>
        ))}
      </div>

      <div style={{ display: "flex", gap: 10, marginTop: 16 }}>
        <button onClick={() => save().catch(() => setMsg("Save failed"))}>Save to Backend</button>
        <button onClick={() => load().catch(() => setMsg("Load failed"))}>Load from Backend</button>
      </div>

      <p style={{ marginTop: 10 }}>{msg}</p>
    </div>
  );
}
