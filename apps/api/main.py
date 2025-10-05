import os, sys
sys.path.append(os.path.dirname(__file__))
from fastapi import FastAPI
from apps.api.services.supabase_sync.sync import router as supabase_router, start_background_sync
app = FastAPI(title="Infinity Codex Core API")
app.include_router(supabase_router)
start_background_sync()
@app.get("/") async def root(): return {"status": "online"}
