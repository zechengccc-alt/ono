"""
Ono AI Backend - FastAPI server
Runs locally, connects to Ollama for AI responses
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import requests
import json
import sqlite3
import os
from datetime import datetime

app = FastAPI(title="Ono AI Backend")

# Enable CORS for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# SQLite database for memory
DB_PATH = os.path.expanduser("~/.ono/memory.db")

def init_db():
    """Initialize SQLite database for persistent memory"""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS conversations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            model TEXT
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_preferences (
            key TEXT PRIMARY KEY,
            value TEXT
        )
    """)
    conn.commit()
    conn.close()

init_db()

class ChatRequest(BaseModel):
    message: str
    model: str = "qwen2.5:3b"
    history: Optional[List[dict]] = []

class ChatResponse(BaseModel):
    response: str
    model: str
    timestamp: str

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    try:
        # Check if Ollama is running
        response = requests.get("http://localhost:11434/api/tags", timeout=2)
        ollama_status = "running" if response.status_code == 200 else "error"
    except:
        ollama_status = "not_running"
    
    return {
        "status": "healthy",
        "ollama": ollama_status,
        "timestamp": datetime.now().isoformat()
    }

@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """Main chat endpoint - forwards to Ollama"""
    try:
        # Build messages for Ollama
        messages = []
        
        # Add system prompt
        messages.append({
            "role": "system",
            "content": """You are Ono, a privacy-first AI assistant that helps users "把糊涂的事理清楚" (make sense of confusing things).

You are:
- Helpful, concise, and friendly
- Privacy-focused (all data stays local)
- Good at summarizing, organizing, and clarifying

Keep responses short and practical. Use Chinese when the user uses Chinese, English otherwise."""
        })
        
        # Add conversation history
        for msg in (request.history or []):
            messages.append({
                "role": msg["role"],
                "content": msg["content"]
            })
        
        # Add current message
        messages.append({
            "role": "user",
            "content": request.message
        })
        
        # Call Ollama API
        response = requests.post(
            "http://localhost:11434/api/chat",
            json={
                "model": request.model,
                "messages": messages,
                "stream": False
            },
            timeout=60
        )
        
        if response.status_code != 200:
            raise HTTPException(status_code=500, detail=f"Ollama error: {response.text}")
        
        data = response.json()
        assistant_message = data.get("message", {}).get("content", "Sorry, I couldn't generate a response.")
        
        # Save to memory
        save_conversation(request.message, request.model, role="user")
        save_conversation(assistant_message, request.model, role="assistant")
        
        return ChatResponse(
            response=assistant_message,
            model=request.model,
            timestamp=datetime.now().isoformat()
        )
        
    except requests.exceptions.Timeout:
        raise HTTPException(status_code=504, detail="Ollama timeout - model might be loading")
    except requests.exceptions.ConnectionError:
        raise HTTPException(status_code=503, detail="Cannot connect to Ollama. Is it running?")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def save_conversation(content: str, model: str, role: str):
    """Save conversation to SQLite"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO conversations (timestamp, role, content, model) VALUES (?, ?, ?, ?)",
        (datetime.now().isoformat(), role, content, model)
    )
    conn.commit()
    conn.close()

@app.get("/api/history")
async def get_history(limit: int = 50):
    """Get conversation history"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT timestamp, role, content, model FROM conversations ORDER BY id DESC LIMIT ?",
        (limit,)
    )
    rows = cursor.fetchall()
    conn.close()
    
    return {
        "history": [
            {"timestamp": r[0], "role": r[1], "content": r[2], "model": r[3]}
            for r in reversed(rows)
        ]
    }

@app.get("/api/models")
async def list_models():
    """List available Ollama models"""
    try:
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        if response.status_code == 200:
            data = response.json()
            return {"models": [m["name"] for m in data.get("models", [])]}
        return {"models": []}
    except:
        return {"models": [], "error": "Cannot connect to Ollama"}

@app.post("/api/preferences")
async def set_preference(key: str, value: str):
    """Set user preference"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "INSERT OR REPLACE INTO user_preferences (key, value) VALUES (?, ?)",
        (key, value)
    )
    conn.commit()
    conn.close()
    return {"status": "saved", "key": key}

@app.get("/api/preferences")
async def get_preferences():
    """Get all user preferences"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT key, value FROM user_preferences")
    rows = cursor.fetchall()
    conn.close()
    return {"preferences": {r[0]: r[1] for r in rows}}

if __name__ == "__main__":
    import uvicorn
    print("🚀 Starting Ono Backend...")
    print("📍 API: http://localhost:8000")
    print("📍 Docs: http://localhost:8000/docs")
    uvicorn.run(app, host="0.0.0.0", port=8000)
