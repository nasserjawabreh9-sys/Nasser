from __future__ import annotations
import os, subprocess
from .state import STATE

ROOT = os.path.expanduser("~/station_root")

def _run(cmd: str, cwd: str | None = None) -> tuple[int, str]:
    p = subprocess.Popen(cmd, cwd=cwd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    out, _ = p.communicate()
    return p.returncode, (out or "").strip()

def core():
    STATE.log("[room:core] start")
    rc, out = _run("ls -la | head", cwd=ROOT)
    STATE.log(f"[room:core] rc={rc}")
    if out: STATE.log(out)

def backend():
    STATE.log("[room:backend] start")
    rc, out = _run("cd backend && python -V && ls -la | head", cwd=ROOT)
    STATE.log(f"[room:backend] rc={rc}")
    if out: STATE.log(out)

def frontend():
    STATE.log("[room:frontend] start")
    rc, out = _run("cd frontend && node -v && npm -v && ls -la | head", cwd=ROOT)
    STATE.log(f"[room:frontend] rc={rc}")
    if out: STATE.log(out)

def tests():
    STATE.log("[room:tests] start")
    rc1, h = _run("curl -s http://127.0.0.1:8000/health || true", cwd=ROOT)
    STATE.log(f"[room:tests] health_rc={rc1} body={h[:160]}")
    rc2, i = _run("curl -s http://127.0.0.1:8000/info || true", cwd=ROOT)
    STATE.log(f"[room:tests] info_rc={rc2} body={i[:160]}")

def git_pipeline():
    STATE.log("[room:git_pipeline] start")
    rc, out = _run("git status -sb || true", cwd=ROOT)
    STATE.log(f"[room:git_pipeline] rc={rc}")
    if out: STATE.log(out)

def render_deploy():
    STATE.log("[room:render_deploy] start")
    STATE.log("[room:render_deploy] hint: Render auto-deploys after GitHub push if connected")
