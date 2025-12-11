#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "===================================="
echo "   🛰 STATION FRONTEND – LOOP V3"
echo "===================================="

ROOT="$HOME/station_root"
FRONT="$ROOT/frontend"
SRC="$FRONT/src"
API_DIR="$SRC/api"

mkdir -p "$API_DIR"
mkdir -p "$SRC/components"

##############################################
# 1) src/api/station_api.ts
##############################################
cat > "$API_DIR/station_api.ts" << 'EOF'
export const STATION_BASE = "http://127.0.0.1:8810";

export interface HealthResponse {
  status: string;
  loop?: string;
  utf8?: boolean;
}

export interface ChatResponse {
  reply: string;
}

async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`HTTP ${res.status}: ${text || res.statusText}`);
  }
  return res.json() as Promise<T>;
}

export async function getHealth(): Promise<HealthResponse> {
  const res = await fetch(`${STATION_BASE}/health`);
  return handleResponse<HealthResponse>(res);
}

export async function sendChat(message: string): Promise<ChatResponse> {
  const res = await fetch(`${STATION_BASE}/api/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message }),
  });
  return handleResponse<ChatResponse>(res);
}
EOF

##############################################
# 2) src/App.tsx
##############################################
cat > "$SRC/App.tsx" << 'EOF'
import React, { useEffect, useState } from "react";
import { getHealth, sendChat, HealthResponse, ChatResponse } from "./api/station_api";

const App: React.FC = () => {
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [healthError, setHealthError] = useState<string | null>(null);

  const [input, setInput] = useState<string>("");
  const [reply, setReply] = useState<string>("");
  const [chatError, setChatError] = useState<string | null>(null);
  const [loading, setLoading] = useState<boolean>(false);

  useEffect(() => {
    // فحص /health عند فتح الواجهة
    getHealth()
      .then((h) => {
        setHealth(h);
        setHealthError(null);
      })
      .catch((err: unknown) => {
        const msg = err instanceof Error ? err.message : String(err);
        setHealthError(msg);
      });
  }, []);

  const handleSend = async () => {
    if (!input.trim()) return;
    setLoading(true);
    setChatError(null);
    setReply("");

    try {
      const res: ChatResponse = await sendChat(input.trim());
      setReply(res.reply);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : String(err);
      setChatError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div
      style={{
        minHeight: "100vh",
        backgroundColor: "#0f172a",
        color: "#e5e7eb",
        padding: "16px",
        fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
      }}
    >
      <div style={{ maxWidth: "900px", margin: "0 auto" }}>
        {/* Header */}
        <header style={{ marginBottom: "24px" }}>
          <h1 style={{ fontSize: "24px", fontWeight: 700, marginBottom: "4px" }}>
            STATION – Termux Loop V3
          </h1>
          <p style={{ fontSize: "14px", color: "#9ca3af" }}>
            Minimal loop بين الواجهة ↔ الباك إند ↔ workspace (بدون مفاتيح، بدون تشغيل تلقائي).
          </p>
        </header>

        <div
          style={{
            display: "grid",
            gridTemplateColumns: "1.1fr 1.4fr",
            gap: "16px",
          }}
        >
          {/* Health Card */}
          <section
            style={{
              borderRadius: "16px",
              background: "#020617",
              padding: "16px",
              border: "1px solid #1e293b",
            }}
          >
            <h2 style={{ fontSize: "16px", fontWeight: 600, marginBottom: "8px" }}>
              Health
            </h2>
            <p style={{ fontSize: "13px", color: "#9ca3af", marginBottom: "8px" }}>
              فحص حالة الباك إند على <code>127.0.0.1:8810/health</code>.
            </p>

            {health && !healthError && (
              <pre
                style={{
                  background: "#020617",
                  borderRadius: "8px",
                  padding: "8px",
                  fontSize: "12px",
                  overflowX: "auto",
                  border: "1px solid #1e293b",
                }}
              >
{`{
  "status": "${health.status}",
  "loop": "${health.loop ?? ""}",
  "utf8": ${health.utf8 ? "true" : "false"}
}`}
              </pre>
            )}

            {healthError && (
              <div
                style={{
                  marginTop: "8px",
                  fontSize: "12px",
                  color: "#fecaca",
                  borderRadius: "8px",
                  padding: "8px",
                  background: "#450a0a",
                  border: "1px solid #b91c1c",
                }}
              >
                HEALTH ERROR: {healthError}
              </div>
            )}
          </section>

          {/* Chat / Loop Card */}
          <section
            style={{
              borderRadius: "16px",
              background: "#020617",
              padding: "16px",
              border: "1px solid #1e293b",
            }}
          >
            <h2 style={{ fontSize: "16px", fontWeight: 600, marginBottom: "8px" }}>
              Loop Chat
            </h2>
            <p style={{ fontSize: "13px", color: "#9ca3af", marginBottom: "8px" }}>
              أرسل رسالة إلى STATION، تُحفظ في <code>workspace/loop_messages.json</code>،
              ويرجع لك رد بسيط (placeholder) من المحرك الداخلي.
            </p>

            <div style={{ marginBottom: "8px" }}>
              <textarea
                value={input}
                onChange={(e) => setInput(e.target.value)}
                rows={3}
                placeholder="اكتب رسالة للاختبار…"
                style={{
                  width: "100%",
                  resize: "vertical",
                  borderRadius: "12px",
                  padding: "8px",
                  border: "1px solid #1e293b",
                  background: "#020617",
                  color: "#e5e7eb",
                  fontSize: "13px",
                  outline: "none",
                }}
              />
            </div>

            <button
              onClick={handleSend}
              disabled={loading || !input.trim()}
              style={{
                borderRadius: "999px",
                padding: "8px 16px",
                fontSize: "13px",
                fontWeight: 500,
                border: "none",
                cursor: loading || !input.trim() ? "not-allowed" : "pointer",
                background: loading || !input.trim() ? "#1f2937" : "#22c55e",
                color: loading || !input.trim() ? "#6b7280" : "#022c22",
                marginBottom: "12px",
              }}
            >
              {loading ? "جارٍ الإرسال…" : "Send to LOOP"}
            </button>

            {reply && (
              <div
                style={{
                  marginBottom: "8px",
                  fontSize: "13px",
                  padding: "8px",
                  borderRadius: "8px",
                  background: "#022c22",
                  border: "1px solid #16a34a",
                  color: "#bbf7d0",
                }}
              >
                <div style={{ fontWeight: 600, marginBottom: "4px" }}>Reply:</div>
                <div>{reply}</div>
              </div>
            )}

            {chatError && (
              <div
                style={{
                  fontSize: "12px",
                  padding: "8px",
                  borderRadius: "8px",
                  background: "#450a0a",
                  border: "1px solid #b91c1c",
                  color: "#fecaca",
                }}
              >
                CHAT ERROR: {chatError}
              </div>
            )}
          </section>
        </div>

        {/* Footer */}
        <footer style={{ marginTop: "24px", fontSize: "11px", color: "#6b7280" }}>
          LOOP V3 – فقط الهيكل: لا تشغيل تلقائي، لا مفاتيح، لا اتصال خارجي.
        </footer>
      </div>
    </div>
  );
};

export default App;
EOF

##############################################
# 3) src/main.tsx (بسيط، بدون CSS إضافي)
##############################################
cat > "$SRC/main.tsx" << 'EOF'
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

echo "===================================="
echo "   ✅ FRONTEND LOOP V3 FILES READY"
echo "   (App.tsx + main.tsx + station_api.ts)"
echo "===================================="
