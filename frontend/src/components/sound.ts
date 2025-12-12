export function playChime() {
  try {
    const ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
    const o = ctx.createOscillator();
    const g = ctx.createGain();
    o.type = "sine";
    o.frequency.value = 523.25; // C5
    g.gain.value = 0.0001;
    o.connect(g);
    g.connect(ctx.destination);
    o.start();

    const t0 = ctx.currentTime;
    g.gain.exponentialRampToValueAtTime(0.18, t0 + 0.03);
    o.frequency.exponentialRampToValueAtTime(659.25, t0 + 0.14); // E5
    o.frequency.exponentialRampToValueAtTime(783.99, t0 + 0.28); // G5
    g.gain.exponentialRampToValueAtTime(0.0001, t0 + 0.55);

    setTimeout(() => {
      o.stop();
      ctx.close();
    }, 700);
  } catch {
    // ignore
  }
}
