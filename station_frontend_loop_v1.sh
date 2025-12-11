#!/data/data/com.termux/files/usr/bin/bash
set -e

echo "===================================="
echo "  🎛 STATION FRONTEND – LOOP V1"
echo "  (React UI فقط، بدون تشغيل)"
echo "===================================="

ROOT="$HOME/station_root"
FRONT="$ROOT/frontend"
SRC="$FRONT/src"
API_DIR="$SRC/api"

mkdir -p "$SRC"
mkdir -p "$API_DIR"
mkdir -p "$SRC/components"

##############################################
# 1) src/api/station_api.ts
##############################################
echo ">>> 1) كتابة src/api/station_api.ts …"

cat > "$API_DIR/station_api.ts" << 'EOF'
const BASE = "http://127.0.0.1:8810";

export interface ChatResponse {
  reply: string;
}

export interface PlanResponse {
  plan: any;
}

export interface ActionsRunResponse {
  result: {
    created_path: string;
    file_name: string;
    plan_status: string;
  };
}

export interface FilesListResponse {
  files: { name: string; size: number }[];
}

async function handleResponse(res: Response) {
  if (!res.ok) {
    const text = await res.text().catch(() => "");
    throw new Error(`HTTP ${res.status} – ${text}`);
  }
  return res.json();
}

export async function sendChat(message: string): Promise<ChatResponse> {
  const res = await fetch(`${BASE}/api/chat`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ message }),
  });
  return handleResponse(res);
}

export async function buildPlan(): Promise<PlanResponse> {
  const res = await fetch(`${BASE}/api/plan`, {
    method: "POST",
  });
  return handleResponse(res);
}

export async function runActions(): Promise<ActionsRunResponse> {
  const res = await fetch(`${BASE}/api/actions/run`, {
    method: "POST",
  });
  return handleResponse(res);
}

export async function listFiles(): Promise<FilesListResponse> {
  const res = await fetch(`${BASE}/api/actions/files`);
  return handleResponse(res);
}
EOF

##############################################
# 2) src/main.tsx
##############################################
echo ">>> 2) كتابة src/main.tsx …"

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

##############################################
# 3) src/App.tsx – لوحة التحكم في الـ LOOP
##############################################
echo ">>> 3) كتابة src/App.tsx …"

cat > "$SRC/App.tsx" << 'EOF'
import React, { useState } from "react";
import {
  sendChat,
  buildPlan,
  runActions,
  listFiles,
} from "./api/station_api";

type LogEntry = {
  ts: string;
  kind: "info" | "error";
  message: string;
};

function now() {
  return new Date().toLocaleTimeString();
}

const App: React.FC = () => {
  const [message, setMessage] = useState("");
  const [reply, setReply] = useState<string>("");
  const [plan, setPlan] = useState<any | null>(null);
  const [actionResult, setActionResult] = useState<any | null>(null);
  const [files, setFiles] = useState<{ name: string; size: number }[]>([]);
  const [logs, setLogs] = useState<LogEntry[]>([]);

  function pushLog(kind: "info" | "error", msg: string) {
    setLogs((prev) => [{ ts: now(), kind, message: msg }, ...prev].slice(0, 50));
  }

  const handleSendChat = async () => {
    if (!message.trim()) {
      pushLog("error", "الرسالة فارغة");
      return;
    }
    try {
      pushLog("info", `إرسال رسالة للـ LOOP: "${message}"`);
      const res = await sendChat(message);
      setReply(res.reply);
      pushLog("info", `رد STATION: ${res.reply}`);
    } catch (err: any) {
      pushLog("error", `خطأ في /api/chat: ${err.message || String(err)}`);
    }
  };

  const handleBuildPlan = async () => {
    try {
      pushLog("info", "طلب بناء خطة من السجل (/api/plan) …");
      const res = await buildPlan();
      setPlan(res.plan);
      pushLog("info", "تم إنشاء plan.json في workspace.");
    } catch (err: any) {
      pushLog("error", `خطأ في /api/plan: ${err.message || String(err)}`);
    }
  };

  const handleRunActions = async () => {
    try {
      pushLog("info", "تشغيل الأفعال (/api/actions/run) …");
      const res = await runActions();
      setActionResult(res.result);
      pushLog(
        "info",
        `تم إنشاء ملف: ${res.result.file_name} – status=${res.result.plan_status}`
      );
    } catch (err: any) {
      pushLog("error", `خطأ في /api/actions/run: ${err.message || String(err)}`);
    }
  };

  const handleListFiles = async () => {
    try {
      pushLog("info", "طلب قائمة ملفات workspace/out …");
      const res = await listFiles();
      setFiles(res.files || []);
      pushLog("info", `ملفات حالية: ${res.files.length}`);
    } catch (err: any) {
      pushLog("error", `خطأ في /api/actions/files: ${err.message || String(err)}`);
    }
  };

  return (
    <div
      style={{
        fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, sans-serif",
        padding: "16px",
        maxWidth: "960px",
        margin: "0 auto",
      }}
    >
      <h1 style={{ fontSize: "1.6rem", marginBottom: "0.25rem" }}>
        STATION – INTERNAL LOOP CONSOLE
      </h1>
      <p style={{ marginTop: 0, color: "#555" }}>
        بناء الـ LOOP داخلياً بدون مفاتيح: chat → log → plan → file.
      </p>

      {/* CHAT */}
      <section
        style={{
          border: "1px solid #ddd",
          borderRadius: "12px",
          padding: "12px",
          marginBottom: "16px",
        }}
      >
        <h2 style={{ fontSize: "1.2rem", marginTop: 0 }}>1) Chat → Log</h2>
        <label style={{ display: "block", marginBottom: "8px" }}>
          رسالة للمحطة:
        </label>
        <textarea
          rows={3}
          style={{ width: "100%", padding: "8px", fontFamily: "inherit" }}
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          placeholder="اكتب رسالة (وصف، أمر، فكرة…) وسيتم حفظها في loop_messages.json"
        />
        <button
          onClick={handleSendChat}
          style={{
            marginTop: "8px",
            padding: "8px 14px",
            borderRadius: "999px",
            border: "none",
            cursor: "pointer",
          }}
        >
          إرسال إلى /api/chat
        </button>
        {reply && (
          <div
            style={{
              marginTop: "8px",
              background: "#f5f5f5",
              padding: "8px",
              borderRadius: "8px",
              whiteSpace: "pre-wrap",
            }}
          >
            <strong>رد STATION:</strong>
            <br />
            {reply}
          </div>
        )}
      </section>

      {/* PLAN */}
      <section
        style={{
          border: "1px solid #ddd",
          borderRadius: "12px",
          padding: "12px",
          marginBottom: "16px",
        }}
      >
        <h2 style={{ fontSize: "1.2rem", marginTop: 0 }}>2) Plan من السجل</h2>
        <button
          onClick={handleBuildPlan}
          style={{
            padding: "8px 14px",
            borderRadius: "999px",
            border: "none",
            cursor: "pointer",
          }}
        >
          بناء خطة (/api/plan)
        </button>
        {plan && (
          <pre
            style={{
              marginTop: "8px",
              background: "#0b1020",
              color: "#e3f4ff",
              padding: "8px",
              borderRadius: "8px",
              maxHeight: "220px",
              overflow: "auto",
              fontSize: "0.8rem",
            }}
          >
            {JSON.stringify(plan, null, 2)}
          </pre>
        )}
      </section>

      {/* ACTIONS */}
      <section
        style={{
          border: "1px solid #ddd",
          borderRadius: "12px",
          padding: "12px",
          marginBottom: "16px",
        }}
      >
        <h2 style={{ fontSize: "1.2rem", marginTop: 0 }}>
          3) Actions → ملفات في workspace/out
        </h2>
        <div style={{ display: "flex", gap: "8px", flexWrap: "wrap" }}>
          <button
            onClick={handleRunActions}
            style={{
              padding: "8px 14px",
              borderRadius: "999px",
              border: "none",
              cursor: "pointer",
            }}
          >
            تشغيل actions (/api/actions/run)
          </button>
          <button
            onClick={handleListFiles}
            style={{
              padding: "8px 14px",
              borderRadius: "999px",
              border: "none",
              cursor: "pointer",
            }}
          >
            تحديث قائمة الملفات
          </button>
        </div>

        {actionResult && (
          <div
            style={{
              marginTop: "8px",
              background: "#f5f5f5",
              padding: "8px",
              borderRadius: "8px",
              fontSize: "0.85rem",
            }}
          >
            <div>
              <strong>آخر ملف منشأ:</strong> {actionResult.file_name}
            </div>
            <div>plan_status: {actionResult.plan_status}</div>
            <div style={{ wordBreak: "break-all" }}>
              path: {actionResult.created_path}
            </div>
          </div>
        )}

        {files.length > 0 && (
          <div style={{ marginTop: "8px" }}>
            <strong>الملفات في workspace/out:</strong>
            <ul style={{ paddingLeft: "20px" }}>
              {files.map((f) => (
                <li key={f.name}>
                  {f.name} <span style={{ color: "#777" }}>({f.size} bytes)</span>
                </li>
              ))}
            </ul>
          </div>
        )}
      </section>

      {/* LOGS */}
      <section
        style={{
          border: "1px solid #ddd",
          borderRadius: "12px",
          padding: "12px",
          marginBottom: "16px",
        }}
      >
        <h2 style={{ fontSize: "1.2rem", marginTop: 0 }}>Logs (محلية)</h2>
        <div
          style={{
            maxHeight: "220px",
            overflow: "auto",
            fontSize: "0.8rem",
            background: "#fafafa",
            padding: "8px",
            borderRadius: "8px",
          }}
        >
          {logs.length === 0 && <div>لا يوجد لوجات بعد.</div>}
          {logs.map((l, idx) => (
            <div
              key={idx}
              style={{
                marginBottom: "4px",
                color: l.kind === "error" ? "#b00020" : "#333",
              }}
            >
              [{l.ts}] {l.kind.toUpperCase()}: {l.message}
            </div>
          ))}
        </div>
      </section>
    </div>
  );
};

export default App;
EOF

echo
echo "===================================="
echo "  ✅ FRONTEND LOOP V1 جاهز (ملفات فقط)"
echo "  لا يوجد تشغيل، ولا لمس للـ npm أو المفاتيح."
echo "===================================="
