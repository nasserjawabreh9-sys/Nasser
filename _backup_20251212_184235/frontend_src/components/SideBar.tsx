export type NavKey = "landing" | "dashboard" | "rooms" | "termux" | "ops" | "about";

type Props = {
  active: NavKey;
  onNav: (k: NavKey) => void;
};

function Item(props: { k: NavKey; label: string; sub: string; active: NavKey; onNav: (k: NavKey) => void }) {
  const isA = props.active === props.k;
  return (
    <div
      className={"navItem " + (isA ? "navItemActive" : "")}
      onClick={() => props.onNav(props.k)}
      role="button"
      tabIndex={0}
    >
      <div style={{ width: 34, height: 34, borderRadius: 12, border: "1px solid rgba(255,255,255,.10)", display: "grid", placeItems: "center", background: "rgba(0,0,0,.14)" }}>
        {props.label.slice(0, 1)}
      </div>
      <div style={{ display: "flex", flexDirection: "column", lineHeight: 1.15 }}>
        <b style={{ fontSize: 13, color: isA ? "rgba(255,255,255,.92)" : "rgba(255,255,255,.68)" }}>{props.label}</b>
        <small style={{ color: "rgba(255,255,255,.55)" }}>{props.sub}</small>
      </div>
    </div>
  );
}

export default function SideBar(p: Props) {
  return (
    <div className="sideBar glass">
      <div style={{ padding: 8 }}>
        <div style={{ fontWeight: 800, marginBottom: 6 }}>Dwarf Armory</div>
        <div style={{ color: "rgba(255,255,255,.60)", fontSize: 12, lineHeight: 1.5 }}>
          Station UI (Vite + React). Windows-style console with ops hooks.
        </div>
      </div>

      <div style={{ height: 10 }} />

      <Item k="landing" label="Landing" sub="Intro & activation" active={p.active} onNav={p.onNav} />
      <Item k="dashboard" label="Dashboard" sub="Chat + health + events" active={p.active} onNav={p.onNav} />
      <Item k="ops" label="Ops" sub="Git/Deploy hooks (stubs)" active={p.active} onNav={p.onNav} />
      <Item k="about" label="About" sub="Build & paths" active={p.active} onNav={p.onNav} />

      <div style={{ marginTop: 14, padding: 10, borderTop: "1px solid rgba(255,255,255,.10)", color: "rgba(255,255,255,.55)", fontSize: 12 }}>
        Hint: set backend URL via <code>VITE_BACKEND_URL</code>
      </div>
    </div>
  );
}
