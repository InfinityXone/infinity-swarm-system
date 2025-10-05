#!/usr/bin/env python3
from fastapi import FastAPI, Request, Form
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from jinja2 import Template
from pathlib import Path
import json, os, datetime

BASE = Path.home() / "infinity-swarm-system"
CHECKLIST = BASE / "docs/machine/build_checklist.json"
REPO_INDEX = BASE / "docs/machine/repo_index.txt"
app = FastAPI()
app.mount("/static", StaticFiles(directory=str(BASE / "frontend/public")), name="static")

# ------------------------------------------------------------------
def load_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except Exception:
        return {}

def list_agents():
    return [f.stem for f in (BASE / "backend/services").glob("*.py")]

def read_logs():
    f = BASE / "logs/full_cloud_sync.log"
    if not f.exists():
        return ["(no logs yet)"]
    return f.read_text().splitlines()[-20:]

def repo_index():
    if not REPO_INDEX.exists():
        return ["(index not found)"]
    return REPO_INDEX.read_text().splitlines()

# ------------------------------------------------------------------
NAV_HTML = """
<div class="sidebar">
  <h2 class="logo">INFINITY SWARM</h2>
  <nav>
    <a href="/">Dashboard</a>
    <a href="#" onclick="openCard('Financial Dashboard','Loading metrics...')">Financial Dashboard</a>
    <a href="#" onclick="openCard('Agents','Loading agent list...')">Agents</a>
    <a href="#" onclick="openCard('Wallets','Loading wallets...')">Wallets</a>
    <a href="#" onclick="openCard('Faucets','Loading faucet data...')">Faucet List</a>
    <a href="#" onclick="openCard('System Health',loadHealthHTML())">System Health</a>
    <a href="#" onclick="openCard('Repo Sync',repoHTML())">Repo Sync</a>
    <a href="#" onclick="openSettings()">Settings</a>
  </nav>
</div>
"""

# ------------------------------------------------------------------
STYLE = """
<style>
body{background:radial-gradient(circle at 20% 20%,#1a1a1a 0%,#0c0c0c 100%);
color:#f0f0f0;font-family:'Inter',sans-serif;margin:0;}
.sidebar{width:230px;height:100vh;position:fixed;left:0;top:0;
background:linear-gradient(180deg,#141414,#0d0d0d);
border-right:1px solid #333;padding:20px;}
.sidebar .logo{font-size:1.2rem;letter-spacing:2px;
color:#fff;margin-bottom:1.5rem;text-transform:uppercase;
border-bottom:1px solid #333;padding-bottom:0.5rem;}
.sidebar nav a{display:block;color:#ccc;text-decoration:none;
padding:8px 0;transition:.2s;}
.sidebar nav a:hover{color:#00e0ff;text-shadow:0 0 6px #00e0ff;}
.main{margin-left:260px;padding:40px;}
h1,h2,h3{color:#fff;letter-spacing:1px;}
.card{background:linear-gradient(180deg,#1c1c1c,#111);
border:1px solid #333;border-radius:8px;padding:20px;margin-bottom:25px;
box-shadow:0 0 20px rgba(0,0,0,0.6);}
table{width:100%;border-collapse:collapse;}
th,td{padding:6px 8px;text-align:left;border-bottom:1px solid #333;}
/* chat + popups */
#chat-bubble{position:fixed;right:30px;bottom:30px;background:#00e0ff;
color:#000;border-radius:50%;width:56px;height:56px;display:flex;
align-items:center;justify-content:center;cursor:pointer;
font-size:24px;font-weight:bold;box-shadow:0 0 15px #00e0ff;}
#chat-panel{position:fixed;right:20px;bottom:100px;width:340px;height:420px;
background:#111;border:1px solid #333;border-radius:8px;display:none;
flex-direction:column;box-shadow:0 0 20px rgba(0,224,255,0.4);z-index:1000;}
.chat-header{background:#0d0d0d;border-bottom:1px solid #333;
padding:8px;display:flex;justify-content:space-between;align-items:center;color:#fff;}
.chat-input{display:flex;border-top:1px solid #333;}
.chat-input input{flex:1;background:#0c0c0c;border:none;color:#fff;padding:8px;}
.chat-input button{background:#00e0ff;border:none;padding:8px 12px;color:#000;cursor:pointer;}
#chat-messages{flex:1;overflow-y:auto;padding:10px;}
.user{color:#00e0ff;margin:4px 0;}
.ai{color:#fff;margin:4px 0;}
.card-popup{position:fixed;top:10%;left:30%;width:40%;
background:linear-gradient(180deg,#1a1a1a,#0e0e0e);
border:1px solid #333;border-radius:10px;
box-shadow:0 0 30px rgba(0,224,255,0.2);color:#fff;z-index:999;}
.card-header{display:flex;justify-content:space-between;padding:10px;border-bottom:1px solid #333;}
.card-header button{background:none;border:none;color:#00e0ff;cursor:pointer;font-size:18px;}
.card-body{padding:15px;}
/* settings modal */
#settings-modal{display:none;position:fixed;top:8%;left:25%;width:50%;height:80%;
background:#101010;border:1px solid #333;border-radius:10px;color:#fff;overflow-y:auto;z-index:1200;
box-shadow:0 0 30px rgba(0,224,255,0.25);}
#settings-modal .head{display:flex;justify-content:space-between;padding:12px;border-bottom:1px solid #333;}
#settings-modal input,#settings-modal textarea{width:100%;background:#0d0d0d;border:1px solid #333;
color:#fff;padding:6px;border-radius:4px;margin-bottom:10px;}
#settings-modal button{background:#00e0ff;border:none;color:#000;padding:6px 12px;margin-top:6px;cursor:pointer;}
</style>
"""

# ------------------------------------------------------------------
@app.get("/", response_class=HTMLResponse)
def dashboard(request: Request):
    data = load_json(CHECKLIST)
    sections = data.get("status", {})
    prog = data.get("progress", {})

    tmpl = Template("""
<html><head><title>Infinity Dashboard</title>{{ style }}</head>
<body>{{ nav }}
<div class="main">
  <h1>System Dashboard</h1>
  <div class="card">
    <h2>Project Status</h2>
    <p>Overall Completion: {{ prog.get('percent',0) }}%</p>
    <table>
      <tr><th>Section</th><th>Completion</th></tr>
      {% for k,v in sections.items() %}
      <tr><td>{{k}}</td><td>{{v.percent}}%</td></tr>
      {% endfor %}
    </table>
  </div>
</div>

<div id="chat-bubble" onclick="toggleChat()">💬</div>

<div id="chat-panel">
  <div class="chat-header"><span>Infinity Chat Console</span>
  <button onclick="toggleChat()">×</button></div>
  <div id="chat-messages"></div>
  <div class="chat-input">
    <input id="chatText" placeholder="Ask Codex or GPT..." onkeypress="if(event.key==='Enter')sendChat()">
    <button onclick="sendChat()">Send</button>
  </div>
</div>

<div id="card-container"></div>

<div id="settings-modal">
  <div class="head">
    <h3>System Settings</h3>
    <button onclick="document.getElementById('settings-modal').style.display='none'">×</button>
  </div>
  <div class="body" style="padding:15px;">
    <h4>Environment Variables</h4>
    <textarea placeholder="Add or edit .env variables here (stub)..."></textarea><button>Save</button>
    <hr/>
    <h4>Accounts</h4>
    <ul>
      <li><a href="https://github.com/InfinityXone" target="_blank">GitHub</a></li>
      <li><a href="https://vercel.com" target="_blank">Vercel</a></li>
      <li><a href="https://supabase.com/dashboard/projects" target="_blank">Supabase</a></li>
      <li><a href="https://console.cloud.google.com" target="_blank">Google Cloud</a></li>
      <li><a href="https://platform.openai.com/account" target="_blank">GPT Account</a></li>
      <li><a href="https://www.coinbase.com" target="_blank">Coinbase</a></li>
      <li><a href="https://phantom.app" target="_blank">Phantom Wallet</a></li>
    </ul>
    <hr/>
    <h4>Appearance</h4>
    <label>Font:</label><input type="text" value="Inter">
    <label>Glow Color:</label><input type="color" value="#00e0ff">
    <label>Background:</label><input type="color" value="#0c0c0c">
    <button>Apply</button>
  </div>
</div>

<script>
// ---------- Frontend logic ----------
function toggleChat(){const p=document.getElementById('chat-panel');
  p.style.display=(p.style.display==='flex')?'none':'flex';}
async function sendChat(){
  const input=document.getElementById('chatText');const msg=input.value.trim();
  if(!msg)return;const m=document.getElementById('chat-messages');
  m.innerHTML+=`<div class='user'>${msg}</div>`;input.value='';
  m.innerHTML+=`<div class='ai'>thinking...</div>`;
  setTimeout(()=>{m.lastChild.innerHTML='(mock) Codex/GPT reply';},700);}
function openCard(title,content){
  const c=document.createElement('div');c.className='card-popup';
  c.innerHTML=`<div class='card-header'><span>${title}</span><button onclick="this.parentElement.parentElement.remove()">×</button></div>
  <div class='card-body'>${content}</div>`;document.getElementById('card-container').appendChild(c);}
function openSettings(){document.getElementById('settings-modal').style.display='block';}
function loadHealthHTML(){return `<pre>CPU: ok\\nMemory: ok\\nAgents: healthy\\nLast Sync: ${new Date().toLocaleTimeString()}</pre>`;}
function repoHTML(){return `<pre>${repo_index.join("\\n")}</pre>`;}
</script>
</body></html>
""")
    return tmpl.render(style=STYLE, nav=NAV_HTML, sections=sections, prog=prog, repo_index=repo_index())

# ------------------------------------------------------------------
@app.post("/repo/update")
async def repo_update(path: str = Form(...), content: str = Form(...)):
    full = BASE / path
    allowed_roots = ["backend", "frontend", "infra", "scripts", "docs"]
    if not any(str(full).startswith(str(BASE / p)) for p in allowed_roots):
        return JSONResponse({"error": "Invalid target folder."}, status_code=403)
    if not full.exists():
        return JSONResponse({"error": "File not found."}, status_code=404)
    with open(full, "w") as f:
        f.write(content)
    return {"status": "ok", "hint": "Saved successfully following repo structure."}
