import { useState } from "react";
import { KeysState } from "./storage";
import { jpost } from "./api";

type Props = { keys: KeysState };

export default function OpsPanel(p: Props) {
  const [out, setOut] = useState<string>("Output will appear here.");

  function guard(): string | null {
    if (!p.keys.editModeKey?.trim()) return "Edit Mode Key missing";
    if (!p.keys.githubToken?.trim()) return "GitHub token missing";
    if (!p.keys.githubRepo?.trim()) return "GitHub repo missing (owner/repo)";
    return null;
  }

  async function run(action: "git_status" | "git_push" | "render_deploy") {
    const g = guard();
    if (g) {
      setOut("Blocked by guard: " + g);
      return;
    }
    try {
      const r = await jpost(`/ops/${action}`, {
        edit_key: p.keys.editModeKey,
        keys: p.keys,
      });
      setOut(JSON.stringify(r, null, 2));
    } catch (e: any) {
      setOut("[stub] backend endpoint not available.\n" + String(e?.message || e));
    }
  }

  return (
    <div className="panel" style={{ height: "100%" }}>
      <div className="panelHeader">
        <h3>Ops Console</h3>
        <span>Guards enabled</span>
      </div>

      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        <button className="btn" onClick={() => void run("git_status")}>Git Status</button>
        <button className="btn btnPrimary" onClick={() => void run("git_push")}>Stage + Commit + Push</button>
        <button className="btn" onClick={() => void run("render_deploy")}>Deploy to Render</button>
      </div>

      <pre style={{ marginTop: 10, padding: 12, borderRadius: 14, border: "1px solid rgba(255,255,255,.10)", background: "rgba(0,0,0,.18)", overflow: "auto", height: "calc(100% - 70px)" }}>
{out}
      </pre>
    </div>
  );
}
