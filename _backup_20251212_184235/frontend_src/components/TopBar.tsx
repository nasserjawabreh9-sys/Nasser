type Props = {
  title: string;
  subtitle: string;
  rightHint?: string;
  onOpenSettings: () => void;
  onClearChat: () => void;
};

export default function TopBar(p: Props) {
  return (
    <div className="topBar">
      <div className="brand">
        <div className="brandBadge" title="Dwarf Armory">
          <span style={{ fontWeight: 900 }}>DA</span>
        </div>
        <div className="brandTitle">
          <div>{p.title}</div>
          <small>{p.subtitle}</small>
        </div>
      </div>

      <div className="topActions">
        {p.rightHint ? <span className="pill">{p.rightHint}</span> : null}
        <button className="btn" onClick={p.onClearChat} title="Clear chat">
          Clear Chat
        </button>
        <button className="btn btnPrimary" onClick={p.onOpenSettings} title="Keys & Settings">
          Settings
        </button>
      </div>
    </div>
  );
}
