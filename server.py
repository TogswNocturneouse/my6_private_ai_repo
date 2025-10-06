# server/server.py
# FastAPI backend for My6PrivateAI - streams logs, manages processes, serves artifacts, requires API key
import asyncio
import os
from pathlib import Path
from fastapi import FastAPI, UploadFile, File, WebSocket, WebSocketDisconnect, HTTPException
from fastapi.responses import FileResponse, JSONResponse
import subprocess
import uvicorn
import aiofiles

WORKDIR = Path("/app/work")
MODELS_DIR = WORKDIR / "models"
ARTIFACTS_DIR = WORKDIR / "artifacts"
MODELS_DIR.mkdir(parents=True, exist_ok=True)
ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)

app = FastAPI(title="My6PrivateAI Backend")
proc = None
proc_lock = asyncio.Lock()
log_clients = set()

API_KEY = os.environ.get("MY6_API_KEY", "devkey_change_this")

def check_api_key(key: str):
    if key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API key")

async def stream_subprocess_output(process: subprocess.Popen):
    try:
        while True:
            line = await asyncio.get_event_loop().run_in_executor(None, process.stdout.readline)
            if not line:
                break
            text = line.decode(errors="ignore")
            disconnected = []
            for ws in list(log_clients):
                try:
                    await ws.send_text(text)
                except Exception:
                    disconnected.append(ws)
            for d in disconnected:
                log_clients.discard(d)
    except Exception as e:
        for ws in list(log_clients):
            try:
                await ws.send_text(f"[stream error] {e}\n")
            except:
                pass

@app.post("/start")
async def start(command: str = None, api_key: str = None):
    check_api_key(api_key)
    global proc
    async with proc_lock:
        if proc and proc.poll() is None:
            return JSONResponse({ "status":"running" })
        if not command:
            command = "python -m http.server 9001"
        proc = subprocess.Popen(command.split(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        asyncio.create_task(stream_subprocess_output(proc))
        return { "status":"started" }

@app.post("/stop")
async def stop(api_key: str = None):
    check_api_key(api_key)
    global proc
    async with proc_lock:
        if not proc:
            return { "status":"not running" }
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        proc = None
        return { "status":"stopped" }

@app.websocket("/ws/logs")
async def websocket_logs(ws: WebSocket):
    await ws.accept()
    log_clients.add(ws)
    try:
        while True:
            await ws.receive_text()
    except WebSocketDisconnect:
        log_clients.discard(ws)

@app.post("/upload_model")
async def upload_model(file: UploadFile = File(...), api_key: str = None):
    check_api_key(api_key)
    dest = MODELS_DIR / file.filename
    async with aiofiles.open(dest, "wb") as f:
        while True:
            chunk = await file.read(2**20)
            if not chunk:
                break
            await f.write(chunk)
    return { "saved": str(dest) }

@app.get("/models")
async def list_models(api_key: str = None):
    check_api_key(api_key)
    return { "models": [p.name for p in MODELS_DIR.iterdir() if p.is_file()] }

@app.get("/artifacts/{fn}")
async def get_artifact(fn: str, api_key: str = None):
    check_api_key(api_key)
    p = ARTIFACTS_DIR / fn
    if not p.exists():
        raise HTTPException(status_code=404, detail="not found")
    return FileResponse(str(p))

@app.post("/api/generate")
async def api_generate(payload: dict, api_key: str = None):
    check_api_key(api_key)
    prompt = payload.get("prompt", "")
    return { "text": f"[echo] {prompt}" }

if __name__ == "__main__":
    uvicorn.run("server:app", host="0.0.0.0", port=8000)
