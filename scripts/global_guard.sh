#!/data/data/com.termux/files/usr/bin/bash
set -u

LOG_DIR="${LOG_DIR:-$HOME/station_root/station_logs}"
mkdir -p "$LOG_DIR"
GUARD_LOG="$LOG_DIR/global_guard.log"

ts(){ date -Iseconds; }
log(){ echo "[$(ts)] $*" | tee -a "$GUARD_LOG" >/dev/null; }

is_cmd(){ command -v "$1" >/dev/null 2>&1; }

ensure_cmds(){
  local missing=0
  for c in ss curl pkill; do
    if ! is_cmd "$c"; then
      log "missing_cmd=$c"
      missing=1
    fi
  done
  if [ "$missing" -eq 1 ]; then
    if is_cmd pkg; then
      log "installing_termux_tools"
      pkg update -y >/dev/null 2>&1 || true
      pkg install -y iproute2 curl procps >/dev/null 2>&1 || true
    fi
  fi
}

port_kill(){
  local port="$1"
  ensure_cmds
  if ss -ltnp 2>/dev/null | grep -qE ":${port}\s"; then
    log "port_busy=$port"
    pkill -f "uvicorn.*--port ${port}" >/dev/null 2>&1 || true
    pkill -f "vite.*--port ${port}" >/dev/null 2>&1 || true
    pkill -f "uvicorn" >/dev/null 2>&1 || true
    pkill -f "vite" >/dev/null 2>&1 || true
    sleep 1
  fi
}

ensure_file(){
  local path="$1"
  local hint="${2:-}"
  if [ ! -f "$path" ]; then
    log "missing_file=$path hint=$hint"
    return 1
  fi
  return 0
}

ensure_dir(){
  local path="$1"
  if [ ! -d "$path" ]; then
    log "missing_dir=$path"
    mkdir -p "$path" || return 1
  fi
  return 0
}

ensure_venv(){
  local be="$1"
  local venv="$be/.venv"
  ensure_dir "$be" || return 1
  if [ ! -d "$venv" ]; then
    log "venv_create=$venv"
    python -m venv "$venv" >/dev/null 2>&1 || return 1
  fi
  # shellcheck disable=SC1090
  source "$venv/bin/activate" >/dev/null 2>&1 || return 1
  python -m pip install -U pip >/dev/null 2>&1 || true
  if [ -f "$be/requirements.txt" ]; then
    log "deps_install=requirements.txt"
    pip install -r "$be/requirements.txt" >/dev/null 2>&1 || return 1
  fi
  return 0
}

health_wait(){
  local url="$1"
  local tries="${2:-20}"
  local i=1
  ensure_cmds
  while [ "$i" -le "$tries" ]; do
    if curl -s "$url" 2>/dev/null | grep -qi "ok"; then
      log "health_ok=$url"
      return 0
    fi
    sleep 1
    i=$((i+1))
  done
  log "health_fail=$url"
  return 1
}

run_with_repair(){
  # Usage:
  # run_with_repair "name" "workdir" "command..."
  local name="$1"; shift
  local cwd="$1"; shift
  local cmd=("$@")

  log "run_start name=$name cwd=$cwd cmd=${cmd[*]}"

  ensure_dir "$cwd" || { log "run_abort name=$name reason=bad_cwd"; return 1; }

  local out="$LOG_DIR/${name}.out.log"
  local err="$LOG_DIR/${name}.err.log"

  ( cd "$cwd" && "${cmd[@]}" ) >"$out" 2>"$err"
  local rc=$?

  if [ "$rc" -eq 0 ]; then
    log "run_ok name=$name"
    return 0
  fi

  # Basic heuristics
  if grep -qiE "address already in use|errno 98" "$err"; then
    log "diagnose=port_conflict name=$name"
    # attempt detect common ports
    for p in 8000 8001 5173 3000; do port_kill "$p"; done
    ( cd "$cwd" && "${cmd[@]}" ) >>"$out" 2>>"$err" || rc=$?
    [ "${rc:-0}" -eq 0 ] && { log "repair_ok name=$name type=port_conflict"; return 0; }
  fi

  if grep -qiE "no such file or directory|not found" "$err"; then
    log "diagnose=missing_file name=$name"
    # no blind creation here; caller should ensure_file/ensure_dir
    return 2
  fi

  if grep -qiE "module not found|no module named" "$err"; then
    log "diagnose=python_deps name=$name"
    return 3
  fi

  log "run_fail name=$name rc=$rc"
  return "$rc"
}

