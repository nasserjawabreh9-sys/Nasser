import { useState } from "react";

type Item = { ts: number; line: string };

export default function TermuxPanel() {
  const [hist, setHist] = useState<Item[]>([
    { ts: Date.now(), line: "Welcome to Station Termux-like Console (UI-only stub)." },
    { ts: Date.now(), line: "Type commands, keep history, copy output. No server execution." },
  ]);
  const [cmd, setCmd] = useState<string>("");

  function runLocal() {
    const c = cmd.trim();
    if (!c) return;
    setCmd("");
    const out =
      c === "help"
        ? "Commands: help | clear | echo <text> | pwd | whoami"
        : c === "clear"
        ? "(cleared)"
        : c.startsWith("echo ")
        ? c.slice(5)
        : c === "pwd"
        ? "/station_root (virtual)"
        : c === "whoami"
        ? "operator"
        : `unknown command: ${c}`;

    setHist((h) => {
      if (c === "clear") return [{ ts: Date.now(), line: "Console cleared." }];
      return [...h, { ts: Date.now(), line: `$ ${c}` }, { ts: Date.now(), line: out }];
    });
  }

  return (
    <div className="panel" style={{ height: "100%" }}>
      <div className="panelHeader">
        <h3>Termux-like</h3>
        <span>UI stub (safe)</span>
      </div>

      <div style={{ height: "calc(100% - 48px)", display: "flex", flexDirection: "column", gap: 10 }}>
        <div style={{ flex: 1, border: "1px solid rgba(255,255,255,.10)", borderRadius: 14, background: "rgba(0,0,0,.18)", padding: 10, overflow: "auto" }}>
          {hist.map((x, i) => (
            <div key={i} style={{ fontFamily: "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace", fontSize: 12, color: "rgba(255,255,255,.82)", whiteSpace: "pre-wrap" }}>
              {x.line}
            </div>
          ))}
        </div>

        <div style={{ display: "flex", gap: 10 }}>
          <input
            value={cmd}
            onChange={(e) => setCmd(e.target.value)}
            placeholder="Type command (help/clear/echo/pwd/whoami)"
            style={{ flex: 1, padding: 12, borderRadius: 14, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.18)", color: "rgba(255,255,255,.9)" }}
            onKeyDown={(e) => {
              if (e.key === "Enter") runLocal();
            }}
          />
          <button className="btn btnPrimary" onClick={runLocal}>Run</button>
        </div>
      </div>
    </div>
  );
}
