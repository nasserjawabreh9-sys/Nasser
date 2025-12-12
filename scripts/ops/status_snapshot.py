import json, os
from datetime import datetime, timezone

ROOT=os.path.expanduser("~/station_root")
EV=os.path.join(ROOT,"station_meta/dynamo/events.jsonl")
OUT=os.path.join(ROOT,"station_meta/status/status.json")

def utc(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def read_events():
    if not os.path.exists(EV): return []
    ev=[]
    with open(EV,"r",encoding="utf-8") as f:
        for line in f:
            line=line.strip()
            if not line: continue
            try: ev.append(json.loads(line))
            except: pass
    return ev

def build_status(events):
    # last status per (mode, root, pipeline, step)
    last={}
    for e in events:
        key=(e.get("mode"), e.get("root_id"), e.get("pipeline"), e.get("step_index"))
        last[key]=e

    # summarize per pipeline
    pipelines={}
    for (mode,rid,pipe,_), e in last.items():
        pk=f"{mode}::R{rid}::{pipe}"
        pipelines.setdefault(pk, {"mode":mode,"root_id":rid,"pipeline":pipe,"last_ts":None,"failed":0,"succeeded":0})
        pipelines[pk]["last_ts"]=max(pipelines[pk]["last_ts"] or "", e.get("ts") or "")
        if e.get("status")=="failed": pipelines[pk]["failed"]+=1
        if e.get("status")=="succeeded": pipelines[pk]["succeeded"]+=1

    # recent tails
    tail=events[-30:] if len(events)>30 else events

    return {
        "generated_utc": utc(),
        "events_total": len(events),
        "pipelines": sorted(pipelines.values(), key=lambda x:(x["mode"],x["root_id"],x["pipeline"])),
        "tail": tail
    }

def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    ev=read_events()
    st=build_status(ev)
    json.dump(st, open(OUT,"w",encoding="utf-8"), ensure_ascii=False, indent=2)
    print(">>> [status_snapshot] wrote station_meta/status/status.json")
    print(f">>> events_total={st['events_total']} pipelines={len(st['pipelines'])}")

if __name__=="__main__":
    main()
