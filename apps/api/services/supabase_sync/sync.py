import os, json, time, threading
from supabase import create_client, Client
from fastapi import APIRouter

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY")
CACHE_PATH = os.path.expanduser("~/infinity-swarm-system/data/supabase_cache.json")
router = APIRouter(prefix="/api/supabase", tags=["Supabase Sync"])

def get_client() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)

def sync_loop():
    client = get_client()
    while True:
        try:
            tables = ["blueprint","memory","logs","agents"]
            snapshot={}
            for t in tables:
                data=client.table(t).select("*").execute()
                snapshot[t]=data.data
            os.makedirs(os.path.dirname(CACHE_PATH),exist_ok=True)
            json.dump(snapshot,open(CACHE_PATH,"w"),indent=2)
            print("[sync] cache updated")
        except Exception as e:
            print("[sync] error",e)
        time.sleep(300)

@router.get("/status")
async def status():
    ok=os.path.exists(CACHE_PATH)
    return {"status":"ok" if ok else "missing"}

def start_bg():
    threading.Thread(target=sync_loop,daemon=True).start()
