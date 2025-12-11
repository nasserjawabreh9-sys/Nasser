#!/data/data/com.termux/files/usr/bin/bash
set -e

echo ">>> [STATION LOOP v3] Frontend setup starting..."

FRONT="$HOME/station_root/frontend"
mkdir -p "$FRONT/src"

cat > "$FRONT/src/App.tsx" << 'TSX'
import React, { useState, useEffect } from "react";

const BACKEND = "http://127.0.0.1:8810";

type TabKey = "health" | "echo" | "loop" | "stats";

interface HealthData {
  status: string;
  service: string;
  port: number;
  features?: string[];
  loop_count?: number;
}

interface LoopCommandOut {
  id: number;
  message: string;
  source: string;
  intent: string;
  tags: string[];
  created_at: string;
}

interface LoopStats {
  total_commands: number;
  by_intent: Record<string, number>;
  by_source: Record<string, number>;
  first_command_at?: string | null;
  last_command_at?: string | null;
}

const App: React.FC = () => {
  const [activeTab, setActiveTab] = useState<TabKey>("health");

  const [health, setHealth] = useState<HealthData | null>(null);
  const [healthError, setHealthError] = useState<string | null>(null);

  const [echoInput, setEchoInput] = useState<string>("هلا");
  const [echoOutput, setEchoOutput] = useState<string>("");

  const [loopMessage, setLoopMessage] = useState<string>("أمر تجريبي من الواجهة");
  const [loopSource, setLoopSource] = useState<string>("frontend");
  const [loopIntent, setLoopIntent] = useState<string>("generic");
  const [loopTags, setLoopTags] = useState<string>("termux,station");
  const [loopResponse, setLoopResponse] = useState<string>("");

  const [loopList, setLoopList] = useState<LoopCommandOut[]>([]);
  const [loopStats, setLoopStats] = useState<LoopStats | null>(null);
  const [statsError, setStatsError] = useState<string | null>(null);

  const fetchHealth = async () => {
    try {
      setHealthError(null);
      const res = await fetch(`${BACKEND}/health`);
      if (!res.ok) {
        throw new Error(`HTTP ${res.status}`);
      }
      const data = await res.json();
      setHealth(data);
    } catch (err: any) {
      setHealthError(String(err));
    }
  };

  const doEcho = async () => {
    try {
      const params = new URLSearchParams({ msg: echoInput });
      const res = await fetch(`${BACKEND}/api/echo?${params.toString()}`);
      const data = await res.json();
      setEchoOutput(JSON.stringify(data, null, 2));
    } catch (err: any) {
      setEchoOutput(`خطأ في الاتصال: ${String(err)}`);
    }
  };

  const sendLoopCommand = async () => {
    try {
      setLoopResponse("");
      const tagsArray = loopTags
        .split(",")
        .map((t) => t.trim())
        .filter((t) => t.length > 0);

      const body = {
        message: loopMessage,
        source: loopSource,
        intent: loopIntent,
        tags: tagsArray,
      };

      const res = await fetch(`${BACKEND}/api/loop/command`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });

      const data = await res.json();
      setLoopResponse(JSON.stringify(data, null, 2));
    } catch (err: any) {
      setLoopResponse(`خطأ في الاتصال: ${String(err)}`);
    }
  };

  const refreshLoopStats = async () => {
    try {
      setStatsError(null);

      const [statsRes, listRes] = await Promise.all([
        fetch(`${BACKEND}/api/loop/stats`),
        fetch(`${BACKEND}/api/loop/list?limit=20`),
      ]);

      if (!statsRes.ok) {
        throw new Error(`stats HTTP ${statsRes.status}`);
      }
      if (!listRes.ok) {
        throw new Error(`list HTTP ${listRes.status}`);
      }

      const statsData = await statsRes.json();
      const listData = await listRes.json();
      setLoopStats(statsData);
      setLoopList(listData);
    } catch (err: any) {
      setStatsError(String(err));
    }
  };

  useEffect(() => {
    fetchHealth().catch(() => {});
  }, []);

  const renderTabButton = (key: TabKey, label: string) => (
    <button
      onClick={() => setActiveTab(key)}
      style={{
        padding: "8px 12px",
        marginRight: "8px",
        borderRadius: "6px",
        border: activeTab === key ? "2px solid #2563eb" : "1px solid #ccc",
        backgroundColor: activeTab === key ? "#eff6ff" : "#f9fafb",
        cursor: "pointer",
      }}
    >
      {label}
    </button>
  );

  const renderHealthTab = () => (
    <div style={{ marginTop: "16px" }}>
      <div style={{ marginBottom: "8px" }}>
        <button
          onClick={fetchHealth}
          style={{
            padding: "6px 10px",
            borderRadius: "6px",
            border: "1px solid #2563eb",
            backgroundColor: "#2563eb",
            color: "#fff",
            cursor: "pointer",
          }}
        >
          تحديث الصحة
        </button>
      </div>
      {healthError && (
        <div style={{ color: "red", marginBottom: "8px" }}>
          خطأ في الصحة: {healthError}
        </div>
      )}
      {health && (
        <pre
          style={{
            backgroundColor: "#0f172a",
            color: "#e5e7eb",
            padding: "12px",
            borderRadius: "8px",
            fontSize: "13px",
            overflowX: "auto",
          }}
        >
{JSON.stringify(health, null, 2)}
        </pre>
      )}
    </div>
  );

  const renderEchoTab = () => (
    <div style={{ marginTop: "16px" }}>
      <div style={{ marginBottom: "8px" }}>
        <label style={{ display: "block", marginBottom: "4px" }}>
          الرسالة:
        </label>
        <input
          value={echoInput}
          onChange={(e) => setEchoInput(e.target.value)}
          style={{
            width: "100%",
            padding: "6px 8px",
            borderRadius: "6px",
            border: "1px solid #d1d5db",
            marginBottom: "8px",
          }}
        />
        <button
          onClick={doEcho}
          style={{
            padding: "6px 10px",
            borderRadius: "6px",
            border: "1px solid #16a34a",
            backgroundColor: "#16a34a",
            color: "#fff",
            cursor: "pointer",
          }}
        >
          إرسال
        </button>
      </div>
      {echoOutput && (
        <pre
          style={{
            backgroundColor: "#0f172a",
            color: "#e5e7eb",
            padding: "12px",
            borderRadius: "8px",
            fontSize: "13px",
            overflowX: "auto",
          }}
        >
{echoOutput}
        </pre>
      )}
    </div>
  );

  const renderLoopTab = () => (
    <div style={{ marginTop: "16px" }}>
      <div style={{ marginBottom: "8px" }}>
        <label style={{ display: "block", marginBottom: "4px" }}>
          الأمر (message):
        </label>
        <textarea
          value={loopMessage}
          onChange={(e) => setLoopMessage(e.target.value)}
          rows={3}
          style={{
            width: "100%",
            padding: "6px 8px",
            borderRadius: "6px",
            border: "1px solid #d1d5db",
            marginBottom: "8px",
          }}
        />
        <label style={{ display: "block", marginBottom: "4px" }}>
          المصدر (source):
        </label>
        <input
          value={loopSource}
          onChange={(e) => setLoopSource(e.target.value)}
          style={{
            width: "100%",
            padding: "6px 8px",
            borderRadius: "6px",
            border: "1px solid #d1d5db",
            marginBottom: "8px",
          }}
        />
        <label style={{ display: "block", marginBottom: "4px" }}>
          النية (intent):
        </label>
        <input
          value={loopIntent}
          onChange={(e) => setLoopIntent(e.target.value)}
          placeholder="generic / build / push / render / termux / agent / llm"
          style={{
            width: "100%",
            padding: "6px 8px",
            borderRadius: "6px",
            border: "1px solid #d1d5db",
            marginBottom: "8px",
          }}
        />
        <label style={{ display: "block", marginBottom: "4px" }}>
          الوسوم (tags) مفصولة بفواصل:
        </label>
        <input
          value={loopTags}
          onChange={(e) => setLoopTags(e.target.value)}
          style={{
            width: "100%",
            padding: "6px 8px",
            borderRadius: "6px",
            border: "1px solid #d1d5db",
            marginBottom: "8px",
          }}
        />
        <button
          onClick={sendLoopCommand}
          style={{
            padding: "6px 10px",
            borderRadius: "6px",
            border: "1px solid #7c3aed",
            backgroundColor: "#7c3aed",
            color: "#fff",
            cursor: "pointer",
          }}
        >
          تسجيل الأمر في loop
        </button>
      </div>
      {loopResponse && (
        <pre
          style={{
            backgroundColor: "#0f172a",
            color: "#e5e7eb",
            padding: "12px",
            borderRadius: "8px",
            fontSize: "13px",
            overflowX: "auto",
          }}
        >
{loopResponse}
        </pre>
      )}
    </div>
  );

  const renderStatsTab = () => (
    <div style={{ marginTop: "16px" }}>
      <div style={{ marginBottom: "8px" }}>
        <button
          onClick={refreshLoopStats}
          style={{
            padding: "6px 10px",
            borderRadius: "6px",
            border: "1px solid #ea580c",
            backgroundColor: "#ea580c",
            color: "#fff",
            cursor: "pointer",
          }}
        >
          تحديث إحصائيات loop
        </button>
      </div>
      {statsError && (
        <div style={{ color: "red", marginBottom: "8px" }}>
          خطأ في الإحصائيات: {statsError}
        </div>
      )}
      {loopStats && (
        <div
          style={{
            padding: "10px",
            borderRadius: "8px",
            border: "1px solid #e5e7eb",
            marginBottom: "12px",
          }}
        >
          <h3 style={{ marginTop: 0, marginBottom: "8px" }}>ملخص loop</h3>
          <div>عدد الأوامر: {loopStats.total_commands}</div>
          <div style={{ marginTop: "4px" }}>
            أول أمر: {loopStats.first_command_at || "—"}
          </div>
          <div style={{ marginTop: "4px" }}>
            آخر أمر: {loopStats.last_command_at || "—"}
          </div>
          <div style={{ marginTop: "8px" }}>
            <strong>حسب intent:</strong>
            <ul>
              {Object.entries(loopStats.by_intent).map(([k, v]) => (
                <li key={k}>
                  {k}: {v}
                </li>
              ))}
            </ul>
          </div>
          <div style={{ marginTop: "8px" }}>
            <strong>حسب source:</strong>
            <ul>
              {Object.entries(loopStats.by_source).map(([k, v]) => (
                <li key={k}>
                  {k}: {v}
                </li>
              ))}
            </ul>
          </div>
        </div>
      )}

      <div
        style={{
          padding: "10px",
          borderRadius: "8px",
          border: "1px solid #e5e7eb",
        }}
      >
        <h3 style={{ marginTop: 0, marginBottom: "8px" }}>آخر أوامر loop</h3>
        {loopList.length === 0 && <div>لا يوجد أوامر بعد.</div>}
        {loopList.length > 0 && (
          <ul style={{ listStyle: "none", padding: 0 }}>
            {loopList.map((cmd) => (
              <li
                key={cmd.id}
                style={{
                  marginBottom: "8px",
                  padding: "8px",
                  borderRadius: "6px",
                  border: "1px solid #e5e7eb",
                  backgroundColor: "#f9fafb",
                }}
              >
                <div>
                  <strong>#{cmd.id}</strong> — intent:{" "}
                  <strong>{cmd.intent}</strong> — source: {cmd.source}
                </div>
                <div style={{ fontSize: "12px", color: "#6b7280" }}>
                  {cmd.created_at}
                </div>
                <div style={{ marginTop: "4px" }}>{cmd.message}</div>
                {cmd.tags && cmd.tags.length > 0 && (
                  <div style={{ marginTop: "4px", fontSize: "12px" }}>
                    tags: {cmd.tags.join(", ")}
                  </div>
                )}
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );

  return (
    <div
      style={{
        fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
        padding: "16px",
        backgroundColor: "#f3f4f6",
        minHeight: "100vh",
        direction: "rtl",
      }}
    >
      <h1 style={{ marginTop: 0, marginBottom: "4px" }}>STATION – Loop v3</h1>
      <p style={{ marginTop: 0, color: "#6b7280", fontSize: "14px" }}>
        محطة صغيرة على تيرمكس لربط الواجهة بالباك-إند، مع loop لتسجيل الأوامر وتحليلها لاحقاً.
      </p>

      <div style={{ marginBottom: "12px" }}>
        {renderTabButton("health", "Health")}
        {renderTabButton("echo", "Echo")}
        {renderTabButton("loop", "Loop Command")}
        {renderTabButton("stats", "Loop Intelligence")}
      </div>

      <div
        style={{
          backgroundColor: "#ffffff",
          borderRadius: "10px",
          padding: "12px",
          boxShadow: "0 1px 3px rgba(0,0,0,0.08)",
        }}
      >
        {activeTab === "health" && renderHealthTab()}
        {activeTab === "echo" && renderEchoTab()}
        {activeTab === "loop" && renderLoopTab()}
        {activeTab === "stats" && renderStatsTab()}
      </div>
    </div>
  );
};

export default App;
TSX

echo ">>> [STATION LOOP v3] Frontend App.tsx updated."
