import os, json, time
from supabase import create_client
SUPABASE_URL=os.getenv("SUPABASE_URL"); SUPABASE_KEY=os.getenv("SUPABASE_SERVICE_ROLE_KEY")
client=create_client(SUPABASE_URL,SUPABASE_KEY)
CACHE=os.path.expanduser("~/infinity-swarm-system/data/semantic_vectors/memory_cache.json")
def loop():
    while True:
        data=client.table("memory").select("*").execute()
        os.makedirs(os.path.dirname(CACHE),exist_ok=True)
        json.dump(data.data,open(CACHE,"w"),indent=2)
        time.sleep(600)
if __name__=="__main__": loop()
