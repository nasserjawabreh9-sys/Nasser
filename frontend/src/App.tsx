import { useEffect, useState } from "react";
import {
  apiHealth,
  apiEcho,
  apiChat,
  apiListTasks,
  apiSubmitTask,
  Health,
  Task,
} from "./api/station_api";

function App() {
  const [health, setHealth] = useState<Health | null>(null);
  const [healthLoading, setHealthLoading] = useState(false);
  const [healthError, setHealthError] = useState<string | null>(null);

  const [echoInput, setEchoInput] = useState("هلا");
  const [echoResult, setEchoResult] = useState<string>("");

  const [chatInput, setChatInput] = useState("");
  const [chatReply, setChatReply] = useState<string>("");

  const [loopInstruction, setLoopInstruction] = useState("");
  const [tasks, setTasks] = useState<Task[]>([]);
  const [loopStatus, setLoopStatus] = useState<string>("");

  // تحميل health عند أول فتح
  useEffect(() => {
    refreshHealth();
    refreshTasks();
  }, []);

  async function refreshHealth() {
    setHealthLoading(true);
    setHealthError(null);
    try {
      const h = await apiHealth();
      setHealth(h);
    } catch (err: any) {
      setHealthError(err?.message ?? "خطأ غير معروف");
    } finally {
      setHealthLoading(false);
    }
  }

  async function handleEcho() {
    try {
      const res = await apiEcho(echoInput || "هلا");
      setEchoResult(res.echo);
    } catch (err: any) {
      setEchoResult("خطأ في /api/echo: " + (err?.message ?? ""));
    }
  }

  async function handleChatSend() {
    if (!chatInput.trim()) return;
    setChatReply("...");
    try {
      const res = await apiChat(chatInput.trim());
      setChatReply(res.reply);
    } catch (err: any) {
      setChatReply("خطأ في /api/chat: " + (err?.message ?? ""));
    }
  }

  async function refreshTasks() {
    try {
      const list = await apiListTasks();
      setTasks(list);
    } catch (err: any) {
      setLoopStatus("خطأ في /api/loop/tasks: " + (err?.message ?? ""));
    }
  }

  async function handleSubmitLoop() {
    if (!loopInstruction.trim()) return;
    setLoopStatus("جاري تسجيل المهمة في اللوب…");
    try {
      await apiSubmitTask("termux_command", loopInstruction.trim());
      setLoopInstruction("");
      await refreshTasks();
      setLoopStatus("✅ تم تسجيل المهمة في اللوب (هيكل فقط بدون تنفيذ).");
    } catch (err: any) {
      setLoopStatus("خطأ في /api/loop/submit: " + (err?.message ?? ""));
    }
  }

  return (
    <div
      style={{
        fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
        background: "#0f172a",
        color: "#e5e7eb",
        minHeight: "100vh",
        padding: "16px",
      }}
    >
      <div style={{ maxWidth: 1000, margin: "0 auto" }}>
        <header style={{ marginBottom: 24 }}>
          <h1 style={{ fontSize: 28, marginBottom: 8 }}>STATION – Termux Loop</h1>
          <p style={{ color: "#9ca3af" }}>
            هيكل محطة بسيطة تربط الواجهة مع الباك-إند وملفات <code>workspace</code> بدون مفاتيح وبدون LLM خارجي.
          </p>
        </header>

        {/* Health & Status */}
        <section
          style={{
            display: "grid",
            gap: 16,
            gridTemplateColumns: "repeat(auto-fit, minmax(260px, 1fr))",
            marginBottom: 24,
          }}
        >
          <div style={{ background: "#111827", borderRadius: 12, padding: 16 }}>
            <h2 style={{ fontSize: 18, marginBottom: 8 }}>Health</h2>
            <button
              onClick={refreshHealth}
              style={{
                padding: "6px 12px",
                borderRadius: 999,
                border: "none",
                background: "#2563eb",
                color: "#f9fafb",
                cursor: "pointer",
                fontSize: 14,
              }}
            >
              تحديث
            </button>
            <div style={{ marginTop: 12, fontSize: 14 }}>
              {healthLoading && <div>… جاري الفحص</div>}
              {healthError && <div style={{ color: "#f97316" }}>{healthError}</div>}
              {health && (
                <div>
                  <div>status: {health.status}</div>
                  <div>loop: {health.loop}</div>
                  <div>utf8: {String(health.utf8)}</div>
                  {health.features && (
                    <div style={{ marginTop: 8 }}>
                      features:
                      <ul style={{ marginTop: 4, paddingLeft: 18 }}>
                        {health.features.map((f) => (
                          <li key={f}>{f}</li>
                        ))}
                      </ul>
                    </div>
                  )}
                </div>
              )}
            </div>
          </div>

          {/* Echo */}
          <div style={{ background: "#111827", borderRadius: 12, padding: 16 }}>
            <h2 style={{ fontSize: 18, marginBottom: 8 }}>/api/echo</h2>
            <div style={{ display: "flex", gap: 8, marginBottom: 8 }}>
              <input
                value={echoInput}
                onChange={(e) => setEchoInput(e.target.value)}
                style={{
                  flex: 1,
                  padding: "6px 10px",
                  borderRadius: 999,
                  border: "1px solid #374151",
                  background: "#020617",
                  color: "#e5e7eb",
                }}
                placeholder="اكتب كلمة للتجربة…"
              />
              <button
                onClick={handleEcho}
                style={{
                  padding: "6px 12px",
                  borderRadius: 999,
                  border: "none",
                  background: "#4b5563",
                  color: "#f9fafb",
                  cursor: "pointer",
                  fontSize: 14,
                }}
              >
                Send
              </button>
            </div>
            <div style={{ fontSize: 14, color: "#9ca3af" }}>
              {echoResult && (
                <>
                  <div>الرد:</div>
                  <pre
                    style={{
                      marginTop: 6,
                      background: "#020617",
                      padding: 8,
                      borderRadius: 8,
                      whiteSpace: "pre-wrap",
                    }}
                  >
                    {echoResult}
                  </pre>
                </>
              )}
            </div>
          </div>
        </section>

        {/* Chat & Loop */}
        <section
          style={{
            display: "grid",
            gap: 16,
            gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))",
          }}
        >
          {/* Chat */}
          <div style={{ background: "#111827", borderRadius: 12, padding: 16 }}>
            <h2 style={{ fontSize: 18, marginBottom: 8 }}>Chat → LOOP Messages</h2>
            <p style={{ fontSize: 13, color: "#9ca3af", marginBottom: 8 }}>
              كل رسالة يتم حفظها في <code>workspace/loop_messages.json</code>.
            </p>
            <textarea
              value={chatInput}
              onChange={(e) => setChatInput(e.target.value)}
              rows={4}
              style={{
                width: "100%",
                padding: 8,
                borderRadius: 8,
                border: "1px solid #374151",
                background: "#020617",
                color: "#e5e7eb",
                fontSize: 14,
                resize: "vertical",
              }}
              placeholder="اكتب رسالة إلى STATION (هيكل فقط)…"
            />
            <div style={{ marginTop: 8, display: "flex", justifyContent: "flex-end" }}>
              <button
                onClick={handleChatSend}
                style={{
                  padding: "6px 14px",
                  borderRadius: 999,
                  border: "none",
                  background: "#22c55e",
                  color: "#022c22",
                  cursor: "pointer",
                  fontSize: 14,
                  fontWeight: 500,
                }}
              >
                Send to LOOP
              </button>
            </div>
            {chatReply && (
              <div style={{ marginTop: 10, fontSize: 14 }}>
                <div style={{ color: "#9ca3af" }}>Reply:</div>
                <pre
                  style={{
                    marginTop: 4,
                    background: "#020617",
                    padding: 8,
                    borderRadius: 8,
                    whiteSpace: "pre-wrap",
                  }}
                >
                  {chatReply}
                </pre>
              </div>
            )}
          </div>

          {/* Loop Tasks */}
          <div style={{ background: "#111827", borderRadius: 12, padding: 16 }}>
            <h2 style={{ fontSize: 18, marginBottom: 8 }}>LOOP Tasks (هيكل)</h2>
            <p style={{ fontSize: 13, color: "#9ca3af", marginBottom: 8 }}>
              هنا نسجّل “أوامر اللوب” فقط. التنفيذ الحقيقي (LLM + Termux + GitHub) يكون لاحقًا.
            </p>

            <textarea
              value={loopInstruction}
              onChange={(e) => setLoopInstruction(e.target.value)}
              rows={3}
              style={{
                width: "100%",
                padding: 8,
                borderRadius: 8,
                border: "1px solid #374151",
                background: "#020617",
                color: "#e5e7eb",
                fontSize: 14,
                resize: "vertical",
              }}
              placeholder="مثال: ابنِ سكربت ينسخ ملفات من تيرمكس إلى GitHub (وصف فقط الآن)…"
            />

            <div style={{ marginTop: 8, display: "flex", gap: 8 }}>
              <button
                onClick={handleSubmitLoop}
                style={{
                  padding: "6px 14px",
                  borderRadius: 999,
                  border: "none",
                  background: "#6366f1",
                  color: "#e5e7eb",
                  cursor: "pointer",
                  fontSize: 14,
                  fontWeight: 500,
                }}
              >
                سجل مهمة في اللوب
              </button>
              <button
                onClick={refreshTasks}
                style={{
                  padding: "6px 14px",
                  borderRadius: 999,
                  border: "1px solid #4b5563",
                  background: "transparent",
                  color: "#e5e7eb",
                  cursor: "pointer",
                  fontSize: 14,
                }}
              >
                تحديث قائمة المهام
              </button>
            </div>

            {loopStatus && (
              <div style={{ marginTop: 8, fontSize: 13, color: "#9ca3af" }}>{loopStatus}</div>
            )}

            <div style={{ marginTop: 12, maxHeight: 220, overflow: "auto", fontSize: 13 }}>
              {tasks.length === 0 ? (
                <div style={{ color: "#6b7280" }}>لا يوجد مهام مسجلة بعد.</div>
              ) : (
                <ul style={{ listStyle: "none", padding: 0, margin: 0 }}>
                  {tasks.map((t) => (
                    <li
                      key={t.id}
                      style={{
                        border: "1px solid #1f2937",
                        borderRadius: 8,
                        padding: 8,
                        marginBottom: 6,
                        background: "#020617",
                      }}
                    >
                      <div style={{ display: "flex", justifyContent: "space-between" }}>
                        <span>#{t.id} – {t.kind}</span>
                        <span style={{ color: "#22c55e" }}>{t.status}</span>
                      </div>
                      {t.payload && t.payload.instruction && (
                        <div style={{ marginTop: 4, color: "#9ca3af" }}>
                          {t.payload.instruction}
                        </div>
                      )}
                    </li>
                  ))}
                </ul>
              )}
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}

export default App;
