#!/usr/bin/env python3
"""
Infinity Swarm Vault System
Manages secure environment variables, secrets, and API keys.
Provides encryption and a dashboard-accessible JSON store.
"""

from cryptography.fernet import Fernet
import os, json, sys, hashlib

CONFIG_DIR = os.path.expanduser("~/.config/cloud")
VAULT_FILE = os.path.join(CONFIG_DIR, "vault.json")
ENC_FILE = VAULT_FILE + ".enc"
KEY_FILE = os.path.join(CONFIG_DIR, "vault.key")

os.makedirs(CONFIG_DIR, exist_ok=True)
if not os.path.exists(KEY_FILE):
    with open(KEY_FILE, "wb") as f:
        f.write(Fernet.generate_key())

fernet = Fernet(open(KEY_FILE, "rb").read())

def load_vault():
    if not os.path.exists(VAULT_FILE):
        json.dump({}, open(VAULT_FILE, "w"), indent=2)
    return json.load(open(VAULT_FILE))

def save_vault(data):
    json.dump(data, open(VAULT_FILE, "w"), indent=2)

def encrypt():
    data = load_vault()
    enc = {k: fernet.encrypt(v.encode()).decode() for k, v in data.items()}
    json.dump(enc, open(ENC_FILE, "w"), indent=2)
    print(f"[vault] Encrypted → {ENC_FILE}")

def decrypt():
    enc = json.load(open(ENC_FILE))
    dec = {k: fernet.decrypt(v.encode()).decode() for k, v in enc.items()}
    save_vault(dec)
    print(f"[vault] Decrypted → {VAULT_FILE}")

def checksum():
    h = hashlib.sha256(open(VAULT_FILE, "rb").read()).hexdigest()
    print(f"[vault] SHA256 checksum: {h}")
    return h

def list_keys():
    data = load_vault()
    print("[vault] Keys:")
    for k in data.keys():
        print(" -", k)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: vault_system.py [encrypt|decrypt|list|checksum]")
        sys.exit(1)
    cmd = sys.argv[1]
    if cmd == "encrypt": encrypt()
    elif cmd == "decrypt": decrypt()
    elif cmd == "list": list_keys()
    elif cmd == "checksum": checksum()
    else:
        print("Invalid command.")
