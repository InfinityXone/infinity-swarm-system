from fastapi import FastAPI
from apps.api.services.supabase_sync.sync import router, start_bg

app = FastAPI(title="Infinity Codex Core API")
app.include_router(router)
start_bg()

@app.get("/")
async def root(): return {"status":"running"}
