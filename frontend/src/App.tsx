import { useEffect, useState } from "react";
import Settings from "./pages/Settings";

function useHashPath() {
  const [path, setPath] = useState<string>(() => (window.location.hash || "#/"));

  useEffect(() => {
    const onHash = () => setPath(window.location.hash || "#/");
    window.addEventListener("hashchange", onHash);
    return () => window.removeEventListener("hashchange", onHash);
  }, []);

  return path;
}

function Nav() {
  const btnStyle: React.CSSProperties = {
    padding: "10px 14px",
    borderRadius: 10,
    border: "1px solid #444",
    background: "#1b1b1b",
    color: "#eee",
    cursor: "pointer",
  };

  return (
    <nav style={{ display: "flex", gap: 10, flexWrap: "wrap", marginBottom: 14 }}>
      <button style={btnStyle} onClick={() => (window.location.hash = "#/")}>Home</button>
      <button style={btnStyle} onClick={() => (window.location.hash = "#/settings")}>Settings</button>
    </nav>
  );
}

function Home() {
  return (
    <div style={{ padding: 16, border: "1px solid #333", borderRadius: 12, background: "#0e0e0e", color: "#ddd" }}>
      <h2 style={{ marginTop: 0 }}>Station UI</h2>
      <p>Use <b>Settings</b> to set keys and run Ops.</p>
      <ul>
        <li>Open: <code>http://127.0.0.1:5173/#/settings</code></li>
        <li>Ops endpoints: <code>/api/ops/git/status</code> and <code>/api/ops/git/push</code></li>
      </ul>
    </div>
  );
}

export default function App() {
  const path = useHashPath();
  const view = (path === "#/settings") ? <Settings /> : <Home />;

  return (
    <div style={{ padding: 12 }}>
      <Nav />
      {view}
    </div>
  );
}
