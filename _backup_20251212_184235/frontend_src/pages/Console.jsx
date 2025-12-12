import React, { useMemo, useState } from "react";

export default function Console() {
  const [line, setLine] = useState("git status");
  const [out, setOut] = useState("");
  const [busy, setBusy] = useState(false);

  const editKey = useMemo(() => {
    try { return localStorage.getItem("edit_mode_key") || "1234"; } catch { return "1234"; }
  }, []);

  async function run() {
    setBusy(true);
    setOut("");
    try {
      const r = await fetch("/api/console", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-Edit-Key": editKey },
        body: JSON.stringify({ line }),
      });
      const j = await r.json();
      setOut(JSON.stringify(j, null, 2));
    } catch (e) {
      setOut(String(e));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div style={{ padding: 16, maxWidth: 1000, margin: "0 auto" }}>
      <h2>Console</h2>
      <p style={{ opacity: 0.8 }}>
        Safe Termux-like console. Allowed: <code>pwd</code>, <code>ls</code>, <code>git status</code>, <code>git log</code>.
        Requires Edit Mode Key.
      </p>

      <div style={{ display: "flex", gap: 8 }}>
        <input
          value={line}
          onChange={(e) => setLine(e.target.value)}
          style={{ flex: 1, padding: 10, borderRadius: 10, border: "1px solid #333" }}
        />
        <button onClick={run} disabled={busy} style={{ padding: "10px 14px", borderRadius: 10 }}>
          {busy ? "Running..." : "Run"}
        </button>
      </div>

      <pre style={{ marginTop: 12, padding: 12, borderRadius: 12, background: "#0b0b0b", color: "#ddd", minHeight: 240, overflow: "auto" }}>
        {out}
      </pre>
    </div>
  );
}
