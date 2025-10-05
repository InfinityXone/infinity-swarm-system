#!/usr/bin/env python3
import json, os, time
from rich import print
from rich.console import Console
from rich.table import Table
from rich.progress import Progress
from pathlib import Path

BASE = Path.home() / "infinity-swarm-system"
CHECKLIST = BASE / "docs/machine/build_checklist.json"
console = Console()

def load_json():
    if not CHECKLIST.exists(): return {}
    with open(CHECKLIST) as f: return json.load(f)

def supabase_ping():
    url = os.getenv("SUPABASE_URL","")
    return "✅" if url else "⚠️ missing"

def drive_ping():
    d = Path.home()/".config"/"rclone"/"rclone.conf"
    return "✅" if d.exists() else "⚠️ not configured"

def main():
    while True:
        os.system("clear")
        data = load_json()
        console.rule("[bold cyan]Infinity Swarm Repo Dashboard[/bold cyan]")
        prog = data.get("progress",{})
        console.print(f"[green]Overall: {prog.get('percent',0)}% complete[/green]")
        t = Table(title="Folder Progress")
        t.add_column("Section"); t.add_column("Files"); t.add_column("Expected"); t.add_column("%")
        for k,v in data.get("status",{}).items():
            t.add_row(k,str(v.get("files_present",0)),str(v.get("files_expected",0)),f"{v.get('percent',0)}%")
        console.print(t)
        console.print(f"[bold]Supabase:[/bold] {supabase_ping()}   [bold]Drive:[/bold] {drive_ping()}")
        console.print("[dim]Press Ctrl+C to exit; refreshes every 60s[/dim]")
        time.sleep(60)

if __name__ == "__main__":
    main()
