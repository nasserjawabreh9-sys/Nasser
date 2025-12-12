import os, json, time
from datetime import datetime, timezone

ROOT=os.path.expanduser("~/station_root")
LOCK_DIR=os.path.join(ROOT,"station_meta","locks")

def utc(): return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def main():
    if not os.path.isdir(LOCK_DIR):
        print(">>> [lock_cleaner] no lock dir")
        return
    now=int(time.time())
    removed=0
    for fn in os.listdir(LOCK_DIR):
        if not fn.endswith(".lock.json"): 
            continue
        path=os.path.join(LOCK_DIR,fn)
        try:
            data=json.load(open(path,"r",encoding="utf-8"))
            acquired=int(data.get("acquired_at",0))
            lease=int(data.get("lease_seconds",0))
            exp=acquired+lease
            if lease>0 and now>exp+5:
                os.remove(path)
                removed+=1
        except Exception:
            # corrupted lock -> remove
            try:
                os.remove(path)
                removed+=1
            except Exception:
                pass
    print(f">>> [lock_cleaner] removed={removed} ts={utc()}")

if __name__=="__main__":
    main()
