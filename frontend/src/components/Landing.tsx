import { useEffect, useState } from "react";
import { playChime } from "./sound";
import { KeysState } from "./storage";

type Props = {
  keys: KeysState;
  onOpenSettings: () => void;
  onEnter: () => void;
};

export default function Landing(p: Props) {
  const [played, setPlayed] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => {
      if (!played) {
        playChime();
        setPlayed(true);
      }
    }, 150);
    return () => clearTimeout(t);
  }, [played]);

  const ready = Boolean(p.keys.openaiKey?.trim());

  return (
    <div className="landing">
      <div className="landingCard glass">
        <div className="hero">
          <div className="quote">"وَفَوْقَ كُلِّ ذِي عِلْمٍ عَلِيمٌ"</div>
          <h1 style={{ marginTop: 10 }}>Station — Official Console</h1>
          <p>
            Landing + Dashboard in one UI. Keys stored in LocalStorage. Backend connectivity + notifications wiring prepared.
          </p>

          <div className="heroFooter">
            <button className="btn btnPrimary" onClick={p.onOpenSettings}>
              Open Settings (Keys)
            </button>
            <button className={"btn " + (ready ? "btnPrimary" : "")} onClick={p.onEnter} disabled={!ready} title={ready ? "Enter dashboard" : "Set OpenAI key first"}>
              Enter Dashboard
            </button>
            {!ready ? <span className="pill">OpenAI key required to activate</span> : <span className="pill" style={{ color: "rgba(61,220,151,.9)" }}>Activated</span>}
          </div>
        </div>

        <div className="animBox">
          <div className="dwarf" title="Armored Dwarf (5s animation)">
            <div className="dwarfInner">DWARF</div>
          </div>
          <div style={{ position: "absolute", bottom: 12, left: 12, right: 12, color: "rgba(255,255,255,.70)", fontSize: 12, lineHeight: 1.5 }}>
            Cartoon movement runs once (5 seconds) on entry. Chime plays on load.
          </div>
        </div>
      </div>
    </div>
  );
}
