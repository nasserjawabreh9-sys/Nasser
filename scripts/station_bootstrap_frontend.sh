#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "[STATION] Frontend bootstrap starting..."

cd "$HOME/station_root"

# Create Vite project if not exists
if [ ! -f "frontend/package.json" ]; then
  echo "[STATION] Creating Vite React-TS project..."
  npm create vite@latest frontend -- --template react-ts
fi

cd frontend

echo "[STATION] Installing npm deps..."
npm install

# Ensure folders
mkdir -p src/api src/components

# stationApi.ts
cat > src/api/stationApi.ts << 'TS'
export type StationConfig = {
  openai_configured: boolean;
  github_configured: boolean;
  backend_version: string;
};

const BACKEND_URL =
  import.meta.env.VITE_STATION_BACKEND_URL || "http://127.0.0.1:8000";

export async function fetchConfig(): Promise<StationConfig> {
  const res = await fetch(`${BACKEND_URL}/config`);
  if (!res.ok) {
    throw new Error(`Config error: ${res.status}`);
  }
  return (await res.json()) as StationConfig;
}

export type ChatMessage = {
  role: "user" | "assistant";
  content: string;
};

export async function sendChat(message: string): Promise<string> {
  const res = await fetch(`${BACKEND_URL}/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message }),
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Chat error: ${res.status} - ${text}`);
  }

  const data = await res.json();
  return data.reply as string;
}
TS

# KeyPanel.tsx
cat > src/components/KeyPanel.tsx << 'TSX'
import React, { useEffect, useState } from "react";

type Props = {
  openaiConfigured: boolean;
  githubConfigured: boolean;
};

const OPENAI_KEY_STORAGE = "station_openai_key_display";
const GITHUB_TOKEN_STORAGE = "station_github_token_display";

export const KeyPanel: React.FC<Props> = ({
  openaiConfigured,
  githubConfigured,
}) => {
  const [openaiKey, setOpenaiKey] = useState("");
  const [githubToken, setGithubToken] = useState("");

  useEffect(() => {
    const savedOpenai = localStorage.getItem(OPENAI_KEY_STORAGE) || "";
    const savedGithub = localStorage.getItem(GITHUB_TOKEN_STORAGE) || "";
    setOpenaiKey(savedOpenai);
    setGithubToken(savedGithub);
  }, []);

  const handleSave = () => {
    localStorage.setItem(OPENAI_KEY_STORAGE, openaiKey);
    localStorage.setItem(GITHUB_TOKEN_STORAGE, githubToken);
    alert("Saved locally in this browser (not sent to backend).");
  };

  return (
    <div className="key-panel" style={{ border: "1px solid #ccc", padding: "12px", borderRadius: "8px", marginBottom: "16px" }}>
      <h2 style={{ marginBottom: "8px" }}>STATION Keys (Browser Only)</h2>
      <p style={{ marginBottom: "8px", fontSize: "0.9rem" }}>
        هذه الحقول تُحفظ في المتصفّح فقط (localStorage). تشغيل الباك إند يعتمد على
        env داخل <code>station_env.sh</code>. يمكنك استخدامها لراحتك فقط.
      </p>
      <div style={{ marginBottom: "8px" }}>
        <label style={{ display: "block", marginBottom: "4px" }}>
          OpenAI Key (display only)
        </label>
        <input
          type="password"
          value={openaiKey}
          onChange={(e) => setOpenaiKey(e.target.value)}
          style={{ width: "100%", padding: "6px" }}
          placeholder="sk-..."
        />
        <small>
          Backend: {openaiConfigured ? "Configured ✅" : "Not configured ❌"}
        </small>
      </div>
      <div style={{ marginBottom: "8px" }}>
        <label style={{ display: "block", marginBottom: "4px" }}>
          GitHub Token (display only)
        </label>
        <input
          type="password"
          value={githubToken}
          onChange={(e) => setGithubToken(e.target.value)}
          style={{ width: "100%", padding: "6px" }}
          placeholder="ghp_..."
        />
        <small>
          Backend: {githubConfigured ? "Configured ✅" : "Not configured ❌"}
        </small>
      </div>
      <button onClick={handleSave} style={{ padding: "6px 12px", marginTop: "4px" }}>
        Save in Browser
      </button>
    </div>
  );
};
TSX

# ChatPanel.tsx
cat > src/components/ChatPanel.tsx << 'TSX'
import React, { useState } from "react";
import { ChatMessage, sendChat } from "../api/stationApi";

export const ChatPanel: React.FC = () => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [input, setInput] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSend = async () => {
    if (!input.trim()) return;
    const userMsg: ChatMessage = { role: "user", content: input.trim() };
    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setError(null);
    setSending(true);
    try {
      const reply = await sendChat(userMsg.content);
      const assistantMsg: ChatMessage = { role: "assistant", content: reply };
      setMessages((prev) => [...prev, assistantMsg]);
    } catch (err: any) {
      setError(err.message || "Error sending message.");
    } finally {
      setSending(false);
    }
  };

  const handleKeyDown: React.KeyboardEventHandler<HTMLInputElement> = (e) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      void handleSend();
    }
  };

  return (
    <div className="chat-panel" style={{ border: "1px solid #ccc", padding: "12px", borderRadius: "8px" }}>
      <h2 style={{ marginBottom: "8px" }}>STATION Chat</h2>
      <div
        style={{
          border: "1px solid #ddd",
          borderRadius: "8px",
          padding: "8px",
          height: "240px",
          overflowY: "auto",
          marginBottom: "8px",
          background: "#fafafa",
        }}
      >
        {messages.length === 0 && (
          <div style={{ fontSize: "0.9rem", color: "#666" }}>
            اكتب رسالة لبدء المحادثة مع STATION...
          </div>
        )}
        {messages.map((m, idx) => (
          <div
            key={idx}
            style={{
              marginBottom: "6px",
              textAlign: m.role === "user" ? "right" : "left",
            }}
          >
            <div
              style={{
                display: "inline-block",
                padding: "6px 8px",
                borderRadius: "8px",
                background: m.role === "user" ? "#e3f2fd" : "#f1f8e9",
                maxWidth: "90%",
              }}
            >
              <strong style={{ fontSize: "0.8rem" }}>
                {m.role === "user" ? "أنت" : "STATION"}
              </strong>
              <div style={{ whiteSpace: "pre-wrap" }}>{m.content}</div>
            </div>
          </div>
        ))}
      </div>
      {error && (
        <div style={{ color: "red", marginBottom: "4px", fontSize: "0.85rem" }}>
          {error}
        </div>
      )}
      <div style={{ display: "flex", gap: "8px" }}>
        <input
          type="text"
          placeholder="اكتب هنا..."
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          style={{ flex: 1, padding: "6px" }}
        />
        <button
          onClick={handleSend}
          disabled={sending}
          style={{ padding: "6px 12px", minWidth: "80px" }}
        >
          {sending ? "..." : "Send"}
        </button>
      </div>
    </div>
  );
};
TSX

# App.tsx
cat > src/App.tsx << 'TSX'
import React, { useEffect, useState } from "react";
import { fetchConfig, StationConfig } from "./api/stationApi";
import { KeyPanel } from "./components/KeyPanel";
import { ChatPanel } from "./components/ChatPanel";

export const App: React.FC = () => {
  const [config, setConfig] = useState<StationConfig | null>(null);
  const [loadingConfig, setLoadingConfig] = useState(true);
  const [configError, setConfigError] = useState<string | null>(null);

  useEffect(() => {
    const loadConfig = async () => {
      try {
        const c = await fetchConfig();
        setConfig(c);
      } catch (err: any) {
        setConfigError(err.message || "Error loading config");
      } finally {
        setLoadingConfig(false);
      }
    };
    void loadConfig();
  }, []);

  return (
    <div
      style={{
        fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
        padding: "12px",
        maxWidth: "960px",
        margin: "0 auto",
      }}
    >
      <header style={{ marginBottom: "16px" }}>
        <h1 style={{ margin: 0 }}>STATION Control</h1>
        <p style={{ margin: "4px 0", fontSize: "0.9rem", color: "#555" }}>
          محطة تشغيل موحّدة (Backend + Frontend) تعمل داخل Termux.
        </p>
        <div style={{ fontSize: "0.85rem", marginTop: "4px" }}>
          {loadingConfig && <span>Loading backend status...</span>}
          {!loadingConfig && config && (
            <>
              <span>Backend version: {config.backend_version}</span>
              <span style={{ marginLeft: "12px" }}>
                OpenAI: {config.openai_configured ? "OK ✅" : "Missing ❌"}
              </span>
              <span style={{ marginLeft: "12px" }}>
                GitHub: {config.github_configured ? "OK ✅" : "Missing ❌"}
              </span>
            </>
          )}
          {!loadingConfig && configError && (
            <span style={{ color: "red" }}>Config error: {configError}</span>
          )}
        </div>
      </header>

      <main style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
        <KeyPanel
          openaiConfigured={!!config?.openai_configured}
          githubConfigured={!!config?.github_configured}
        />
        <ChatPanel />
      </main>
    </div>
  );
};

export default App;
TSX

# main.tsx
cat > src/main.tsx << 'TSX'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
TSX

echo "[STATION] Frontend bootstrap done."
