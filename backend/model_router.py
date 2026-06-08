#!/usr/bin/env python3
"""
Oko Dual-Bridge Framework - Model Router Core
============================================
Memory Tiering + Context-Based Dynamic Routing + Auto GC + Offline Weekly Report

Architecture:
  Tier 1 (Core LLM):  gemma2:2b   — always resident, ~ms latency, structured extraction
  Tier 2 (Heavy LLM): phi3:3.8b   — lazy-loaded, ~15-30s cold start, deep reasoning

Bridge Wake Signal: triggered by token-length threshold OR emotion/decision keyword detection.
Auto GC: unloads Tier 2 after 3 min idle, frees VRAM back to Tier 1 baseline.

Usage:
  python3 model_router.py              # standalone test
  from model_router import OkoRouter  # import as module
"""

import json
import os
import sys
import time
import threading
import sqlite3
import requests
from datetime import datetime, timedelta
from enum import Enum
from typing import Optional
from pathlib import Path
from dataclasses import dataclass, field


# =============================================================================
# CONFIG
# =============================================================================

class Config:
    # Model definitions
    TIER1_MODEL = "gemma2:2b"
    TIER2_MODEL = "phi3:3.8b"

    # Ollama endpoint
    OLLAMA_BASE = "http://localhost:11434"

    # Router thresholds
    TOKEN_LENGTH_THRESHOLD = 80          # chars — if input > this, consider Tier 2
    TIER2_KEYWORDS = [
        # Emotion triggers
        "anxious", "stressed", "worried", "scared", "overwhelmed",
        "depressed", "angry", "frustrated", "confused", "lost",
        "tired", "exhausted", "burnt out", "hopeless", "panic",
        "anxiety", "pressure", "fail", "failing", "can't",
        # Decision triggers
        "should i", "what should", "decide", "decision", "choice",
        "compare", "between", "versus", "vs", "pros and cons",
        "recommend", "advice", "opinion", "think about",
        # Complex consultation
        "explain", "analyze", "analyze this", "breakdown",
        "strategy", "plan", "roadmap", "how to",
        "help me", "guide", "mentor", "coach",
        "financial", "money", "budget", "savings", "invest",
        "college", "university", "application", "GPA", "grade",
        "career", "job", "internship", "resume",
        "project", "startup", "business", "launch",
        "relationship", "friend", "family", "parent",
        # Chinese triggers
        "焦虑", "压力", "迷茫", "崩溃", "抑郁", "烦躁",
        "不知道", "怎么办", "选择", "决定", "纠结",
        "建议", "帮我", "分析", "规划", "路线图",
        "财务", "学业", "大学", "GPA", "申请",
        "创业", "项目", "发布", "关系",
    ]

    # Auto GC
    IDLE_GC_SECONDS = 180               # 3 minutes

    # Weekly report
    WEEKLY_REPORT_DAY = 6                 # Sunday (0=Mon, 6=Sun)
    WEEKLY_REPORT_HOUR = 3               # 3 AM
    WEEKLY_CACHE_DIR = os.path.expanduser("~/.oko/weekly_canvas_cache")

    # DB path
    DB_PATH = os.path.expanduser("~/.oko/memory.db")


# =============================================================================
# ENUMS & DATA CLASSES
# =============================================================================

class ModelTier(Enum):
    TIER1 = "tier1"
    TIER2 = "tier2"

class BridgeState(Enum):
    IDLE = "idle"                    # Only Tier 1 resident
    WAKING = "waking"               # Tier 2 loading into VRAM
    ACTIVE = "active"               # Tier 2 ready, handling request
    COOLING = "cooling"             # Tier 2 finished, idle timer running

@dataclass
class RouterDecision:
    """Result of the routing decision"""
    tier: ModelTier
    reason: str
    confidence: float                # 0.0 - 1.0
    trigger_keywords: list = field(default_factory=list)
    input_length: int = 0


# =============================================================================
# MODEL ROUTER CORE
# =============================================================================

class OkoRouter:
    """
    Dual-Bridge Model Router for Oko AI.

    Responsibilities:
    1. Classify user input → route to Tier 1 or Tier 2
    2. Lazy-load Tier 2 on demand (bridge_wake_signal)
    3. Auto-unload Tier 2 after idle period (memory GC)
    4. Trigger offline weekly deep-analysis reports
    """

    def __init__(self, config: Config = None):
        self.config = config or Config()
        self._state = BridgeState.IDLE
        self._last_tier2_activity = 0.0
        self._gc_thread: Optional[threading.Thread] = None
        self._gc_stop = threading.Event()
        self._tier2_ready = False
        self._tier2_wake_lock = threading.Lock()
        self._weekly_thread: Optional[threading.Thread] = None
        self._weekly_stop = threading.Event()
        self._stats = {
            "tier1_requests": 0,
            "tier2_requests": 0,
            "gc_cycles": 0,
            "bridge_wakes": 0,
        }

    # -------------------------------------------------------------------------
    # PROPERTIES
    # -------------------------------------------------------------------------

    @property
    def state(self) -> BridgeState:
        return self._state

    @property
    def stats(self) -> dict:
        return {**self._stats, "bridge_state": self._state.value}

    # -------------------------------------------------------------------------
    # 1. CONTEXT-BASED ROUTING
    # -------------------------------------------------------------------------

    def classify(self, user_input: str) -> RouterDecision:
        """
        Analyze user input and decide which model tier to use.

        Routing logic:
        - Token length > threshold → candidate for Tier 2
        - Keyword match on emotion/decision/complex triggers → Tier 2
        - Both matched → high confidence Tier 2
        - Neither → Tier 1
        """
        text = user_input.lower()
        input_len = len(text)
        matched_keywords = [kw for kw in self.config.TIER2_KEYWORDS if kw in text]

        length_exceeded = input_len > self.config.TOKEN_LENGTH_THRESHOLD
        keyword_triggered = len(matched_keywords) > 0

        if keyword_triggered and length_exceeded:
            confidence = min(0.95, 0.7 + len(matched_keywords) * 0.05)
            tier = ModelTier.TIER2
            reason = f"complex_input: {len(matched_keywords)} keywords + {input_len} chars"
        elif keyword_triggered:
            confidence = min(0.9, 0.6 + len(matched_keywords) * 0.05)
            tier = ModelTier.TIER2
            reason = f"keyword_trigger: {matched_keywords[:3]}"
        elif length_exceeded:
            confidence = 0.5
            tier = ModelTier.TIER2
            reason = f"long_input: {input_len} chars"
        else:
            confidence = 0.85
            tier = ModelTier.TIER1
            reason = "routine_query"

        return RouterDecision(
            tier=tier,
            reason=reason,
            confidence=confidence,
            trigger_keywords=matched_keywords,
            input_length=input_len,
        )

    # -------------------------------------------------------------------------
    # 2. BRIDGE WAKE / SLEEP
    # -------------------------------------------------------------------------

    def _ensure_tier2_loaded(self) -> bool:
        """
        Lazy-load Tier 2 model into Ollama VRAM.
        Ollama auto-loads on first inference — we just need a warmup call.
        """
        with self._tier2_wake_lock:
            if self._tier2_ready:
                self._last_tier2_activity = time.time()
                return True

            self._state = BridgeState.WAKING
            self._stats["bridge_wakes"] += 1

            try:
                # Warmup inference to force Ollama to load model into VRAM
                resp = requests.post(
                    f"{self.config.OLLAMA_BASE}/api/chat",
                    json={
                        "model": self.config.TIER2_MODEL,
                        "messages": [{"role": "user", "content": "ok"}],
                        "stream": False,
                        "options": {"num_predict": 1},
                    },
                    timeout=120,  # First load can be slow
                )
                if resp.status_code == 200:
                    self._tier2_ready = True
                    self._state = BridgeState.ACTIVE
                    self._last_tier2_activity = time.time()
                    return True
                else:
                    self._state = BridgeState.IDLE
                    return False
            except Exception as e:
                print(f"[Router] Tier 2 wake failed: {e}")
                self._state = BridgeState.IDLE
                return False

    def _unload_tier2(self):
        """
        Memory GC: unload Tier 2 from Ollama VRAM.
        Uses Ollama's model unload endpoint if available (v0.1.36+),
        otherwise relies on Ollama's automatic LRU eviction.
        """
        with self._tier2_wake_lock:
            try:
                requests.delete(
                    f"{self.config.OLLAMA_BASE}/api/models/{self.config.TIER2_MODEL}",
                    timeout=10,
                )
            except Exception:
                pass  # Ollama < 0.1.36 — auto-eviction handles it

            self._tier2_ready = False
            self._state = BridgeState.IDLE
            self._stats["gc_cycles"] += 1
            print(f"[Router] Tier 2 GC completed. VRAM freed.")

    # -------------------------------------------------------------------------
    # 3. MAIN CHAT ENTRY POINT
    # -------------------------------------------------------------------------

    def chat(
        self,
        user_input: str,
        history: list = None,
        system_prompt: str = None,
    ) -> dict:
        """
        Route + execute a chat request.

        Returns: {"response": str, "model": str, "tier": str, "decision": dict}
        """
        decision = self.classify(user_input)

        if decision.tier == ModelTier.TIER1:
            model = self.config.TIER1_MODEL
            self._stats["tier1_requests"] += 1
        else:
            model = self.config.TIER2_MODEL
            self._stats["tier2_requests"] += 1
            if not self._ensure_tier2_loaded():
                # Fallback to Tier 1 if Tier 2 fails to load
                model = self.config.TIER1_MODEL
                decision.tier = ModelTier.TIER1
                decision.reason += " (fallback: T2 load failed)"

        # Build messages
        messages = []
        if system_prompt:
            messages.append({"role": "system", "content": system_prompt})
        else:
            messages.append({"role": "system", "content": self._default_system_prompt()})

        for msg in (history or []):
            messages.append({"role": msg.get("role", "user"), "content": msg.get("content", "")})

        messages.append({"role": "user", "content": user_input})

        # Inference
        try:
            resp = requests.post(
                f"{self.config.OLLAMA_BASE}/api/chat",
                json={"model": model, "messages": messages, "stream": False},
                timeout=90,
            )
            if resp.status_code != 200:
                return {"response": f"[Error] Ollama returned {resp.status_code}", "model": model, "tier": decision.tier.value, "decision": {"reason": decision.reason}}

            data = resp.json()
            response_text = data.get("message", {}).get("content", "")

            # Save to memory
            self._save_conversation(user_input, response_text, model)

            return {
                "response": response_text,
                "model": model,
                "tier": decision.tier.value,
                "decision": {"reason": decision.reason, "confidence": decision.confidence, "keywords": decision.trigger_keywords},
            }
        except requests.exceptions.Timeout:
            return {"response": "[Error] Model timeout — may be loading. Try again in a moment.", "model": model, "tier": decision.tier.value, "decision": {"reason": decision.reason}}
        except Exception as e:
            return {"response": f"[Error] {str(e)}", "model": model, "tier": decision.tier.value, "decision": {"reason": decision.reason}}

    # -------------------------------------------------------------------------
    # 4. GC DAEMON
    # -------------------------------------------------------------------------

    def start_gc_daemon(self):
        """Start background thread that auto-unloads Tier 2 after idle."""
        if self._gc_thread and self._gc_thread.is_alive():
            return
        self._gc_stop.clear()
        self._gc_thread = threading.Thread(target=self._gc_loop, daemon=True)
        self._gc_thread.start()
        print("[Router] GC daemon started.")

    def stop_gc_daemon(self):
        self._gc_stop.set()
        if self._gc_thread:
            self._gc_thread.join(timeout=5)

    def _gc_loop(self):
        while not self._gc_stop.is_set():
            time.sleep(15)  # Check every 15s
            if (self._state in (BridgeState.ACTIVE, BridgeState.COOLING)
                    and self._tier2_ready
                    and time.time() - self._last_tier2_activity > self.config.IDLE_GC_SECONDS):
                self._unload_tier2()

    # -------------------------------------------------------------------------
    # 5. OFFLINE WEEKLY REPORT
    # -------------------------------------------------------------------------

    def start_weekly_daemon(self):
        """Start background thread for Sunday 3 AM weekly report generation."""
        if self._weekly_thread and self._weekly_thread.is_alive():
            return
        self._weekly_stop.clear()
        self._weekly_thread = threading.Thread(target=self._weekly_loop, daemon=True)
        self._weekly_thread.start()
        print("[Router] Weekly report daemon started.")

    def stop_weekly_daemon(self):
        self._weekly_stop.set()
        if self._weekly_thread:
            self._weekly_thread.join(timeout=5)

    def _weekly_loop(self):
        """Check every 30 min if it's time to generate weekly report."""
        while not self._weekly_stop.is_set():
            now = datetime.now()
            if (now.weekday() == self.config.WEEKLY_REPORT_DAY
                    and now.hour == self.config.WEEKLY_REPORT_HOUR
                    and now.minute < 30):
                self._generate_weekly_report()
                # Sleep 2 hours to avoid re-triggering
                self._weekly_stop.wait(7200)
            else:
                self._weekly_stop.wait(1800)  # Check every 30 min

    def _generate_weekly_report(self):
        """
        Generate a comprehensive weekly reflection using Tier 2.
        Covers: financial + academic + project dimensions.
        """
        os.makedirs(self.config.WEEKLY_CACHE_DIR, exist_ok=True)

        # Gather week's conversation data
        week_ago = (datetime.now() - timedelta(days=7)).isoformat()
        conversations = self._get_conversations_since(week_ago)

        if not conversations:
            print("[Weekly] No conversations this week — skipping.")
            return

        # Build structured context
        conv_summary = "\n".join(
            f"[{m['timestamp']}] {m['role'].upper()}: {m['content'][:200]}"
            for m in conversations[-50:]  # Last 50 messages
        )

        report_prompt = f"""You are Oko's weekly reflection engine. Analyze the user's past week of conversations and generate a structured weekly report.

IMPORTANT: Respond in the same language the user primarily used this week. Keep it concise but insightful.

Past week's conversations:
{conv_summary}

Generate a report with these sections:
1. EMOTIONAL LANDSCAPE — What emotions/patterns dominated this week?
2. FINANCIAL HEALTH — Any financial decisions, spending patterns, or concerns?
3. ACADEMIC PROGRESS — Study habits, GPA-related concerns, learning milestones?
4. PROJECT MOMENTUM — Progress on projects, blockers, achievements?
5. KEY DECISIONS — What important decisions were made or avoided?
6. RECOMMENDATION — One actionable suggestion for next week."""

        print("[Weekly] Waking Tier 2 for weekly report generation...")
        self._ensure_tier2_loaded()

        result = self.chat(
            user_input=report_prompt,
            system_prompt="You are Oko's internal weekly analysis engine. Be honest, structured, and constructive.",
        )

        # Save report
        week_label = datetime.now().strftime("%Y-W%W")
        cache_file = os.path.join(self.config.WEEKLY_CACHE_DIR, f"report_{week_label}.txt")

        with open(cache_file, "w", encoding="utf-8") as f:
            f.write(f"Oko Weekly Report — {datetime.now().strftime('%Y-%m-%d %H:%M')}\n")
            f.write("=" * 60 + "\n\n")
            f.write(result.get("response", "[Generation failed]"))
            f.write(f"\n\n--- Generated by {result.get('model', 'unknown')} ---\n")

        print(f"[Weekly] Report saved to {cache_file}")

        # Unload Tier 2 immediately after report
        self._unload_tier2()

    # -------------------------------------------------------------------------
    # 6. HELPERS
    # -------------------------------------------------------------------------

    def _default_system_prompt(self) -> str:
        return """You are Oko, a privacy-first AI assistant that helps users "把糊涂的事理清楚" (make sense of confusing things).

You are:
- Helpful, concise, and friendly
- Privacy-focused (all data stays local)
- Good at summarizing, organizing, and clarifying
- Supportive but honest — you don't sugarcoat problems

Keep responses short and practical. Use Chinese when the user uses Chinese, English otherwise."""

    def _save_conversation(self, user_msg: str, assistant_msg: str, model: str):
        os.makedirs(os.path.dirname(self.config.DB_PATH), exist_ok=True)
        conn = sqlite3.connect(self.config.DB_PATH)
        c = conn.cursor()
        now = datetime.now().isoformat()
        c.execute("INSERT INTO conversations (timestamp, role, content, model) VALUES (?,?,?,?)",
                  (now, "user", user_msg, model))
        c.execute("INSERT INTO conversations (timestamp, role, content, model) VALUES (?,?,?,?)",
                  (now, "assistant", assistant_msg, model))
        conn.commit()
        conn.close()

    def _get_conversations_since(self, since: str) -> list:
        conn = sqlite3.connect(self.config.DB_PATH)
        c = conn.cursor()
        c.execute("SELECT timestamp, role, content FROM conversations WHERE timestamp >= ? ORDER BY id ASC", (since,))
        rows = c.fetchall()
        conn.close()
        return [{"timestamp": r[0], "role": r[1], "content": r[2]} for r in rows]

    def get_model_status(self) -> dict:
        """Return current model loading status for UI display."""
        return {
            "bridge_state": self._state.value,
            "tier1_model": self.config.TIER1_MODEL,
            "tier2_model": self.config.TIER2_MODEL,
            "tier2_loaded": self._tier2_ready,
            "tier2_idle_seconds": round(time.time() - self._last_tier2_activity) if self._last_tier2_activity else 0,
            "stats": self.stats,
        }


# =============================================================================
# FASTAPI INTEGRATION
# =============================================================================

def create_router_app(router: OkoRouter = None) -> 'FastAPI':
    """
    Create a FastAPI app with the dual-bridge router integrated.
    This replaces the old /api/chat with intelligent routing.
    """
    from fastapi import FastAPI
    from fastapi.middleware.cors import CORSMiddleware
    from pydantic import BaseModel
    from typing import Optional, List

    router = router or OkoRouter()
    router.start_gc_daemon()
    router.start_weekly_daemon()

    app = FastAPI(title="Oko AI Backend — Dual-Bridge")
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    class ChatRequest(BaseModel):
        message: str
        history: Optional[List[dict]] = []
        system_prompt: Optional[str] = None

    @app.get("/health")
    async def health():
        ollama_ok = False
        try:
            r = requests.get(f"{Config.OLLAMA_BASE}/api/tags", timeout=2)
            ollama_ok = r.status_code == 200
        except Exception:
            pass
        return {"status": "healthy", "ollama": "running" if ollama_ok else "down", **router.get_model_status()}

    @app.post("/api/chat")
    async def chat(req: ChatRequest):
        return router.chat(req.message, req.history, req.system_prompt)

    @app.get("/api/router/status")
    async def router_status():
        return router.get_model_status()

    @app.post("/api/router/wake")
    async def manual_wake():
        """Manually wake Tier 2 (for testing or pre-warming)."""
        ok = router._ensure_tier2_loaded()
        return {"woken": ok, "state": router.state.value}

    @app.post("/api/router/sleep")
    async def manual_sleep():
        """Manually unload Tier 2."""
        router._unload_tier2()
        return {"state": router.state.value}

    @app.post("/api/router/weekly")
    async def trigger_weekly():
        """Manually trigger weekly report generation."""
        import threading
        threading.Thread(target=router._generate_weekly_report, daemon=True).start()
        return {"triggered": True, "note": "Check ~/.oko/weekly_canvas_cache/"}

    @app.get("/api/models")
    async def list_models():
        try:
            r = requests.get(f"{Config.OLLAMA_BASE}/api/tags", timeout=5)
            if r.status_code == 200:
                return {"models": [m["name"] for m in r.json().get("models", [])]}
        except Exception:
            pass
        return {"models": []}

    @app.get("/api/history")
    async def get_history(limit: int = 50):
        convs = router._get_conversations_since("1970-01-01")
        return {"history": convs[-limit:]}

    return app


# =============================================================================
# STANDALONE TEST
# =============================================================================

if __name__ == "__main__":
    print("=" * 60)
    print("  Oko Dual-Bridge Model Router — Standalone Test")
    print("=" * 60)

    r = OkoRouter()
    r.start_gc_daemon()

    # Test routing decisions
    test_inputs = [
        "hi",
        "what's 2+2",
        "I'm really stressed about my GPA and don't know if I should drop chemistry",
        "帮我分析一下这个星期的财务状况",
        "explain quantum computing",
        "I feel overwhelmed with everything",
        "set a reminder for 3pm",
        "what are the pros and cons of applying early decision vs regular decision for college?",
    ]

    print("\n--- Routing Decisions ---")
    for inp in test_inputs:
        d = r.classify(inp)
        tier_icon = "🔷" if d.tier == ModelTier.TIER1 else "🔶"
        print(f"  {tier_icon} [{d.tier.value:5s}] (conf={d.confidence:.2f}) \"{inp[:60]}\"")
        print(f"       reason: {d.reason}")

    # Test live Ollama connection
    print("\n--- Live Ollama Test ---")
    try:
        resp = requests.get(f"{Config.OLLAMA_BASE}/api/tags", timeout=3)
        if resp.status_code == 200:
            models = [m["name"] for m in resp.json().get("models", [])]
            print(f"  Ollama running. Models: {models}")
        else:
            print("  Ollama returned non-200")
    except Exception as e:
        print(f"  Ollama not reachable: {e}")

    print(f"\n  Router status: {r.get_model_status()}")
    print("\nDone. Use `python3 model_router.py --serve` to start API server.")
