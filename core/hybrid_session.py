"""
Hybrid session manager that can use either OpenAI or local models.
Provides seamless switching between cloud and local AI services.
"""

import asyncio
from typing import Any, Dict, Optional

from .config import USE_LOCAL_MODELS
from .session import BillySession
from .local_session import LocalBillySession


class HybridBillySession:
    """Hybrid session manager supporting both OpenAI and local models."""
    
    def __init__(self, interrupt_event=None):
        self.interrupt_event = interrupt_event
        self.openai_session: Optional[BillySession] = None
        self.local_session: Optional[LocalBillySession] = None
        self.current_session = None
        self.use_local = USE_LOCAL_MODELS
    
    async def start(self):
        """Start the appropriate session based on configuration."""
        print(f"\n🚀 Starting hybrid session (local models: {self.use_local})")
        
        if self.use_local:
            self.local_session = LocalBillySession(self.interrupt_event)
            success = await self.local_session.start()
            if success:
                self.current_session = self.local_session
                print("✅ Local model session active")
                return True
            else:
                print("⚠️ Local models failed, falling back to OpenAI")
                self.use_local = False
        
        if not self.use_local:
            self.openai_session = BillySession(self.interrupt_event)
            await self.openai_session.start()
            self.current_session = self.openai_session
            print("✅ OpenAI session active")
            return True
        
        return False
    
    async def stop(self):
        """Stop the current session."""
        if self.current_session:
            if self.use_local and self.local_session:
                await self.local_session.stop()
            elif not self.use_local and self.openai_session:
                await self.openai_session.stop()
            self.current_session = None
    
    async def process_audio_input(self, audio_data: bytes) -> Optional[str]:
        """Process audio input using the current session."""
        if not self.current_session:
            return None
        
        if self.use_local and self.local_session:
            return await self.local_session.process_audio_input(audio_data)
        elif not self.use_local and self.openai_session:
            # OpenAI session handles audio differently
            return None
        
        return None
    
    async def generate_response(self, user_input: str):
        """Generate response using the current session."""
        if not self.current_session:
            return
        
        if self.use_local and self.local_session:
            async for chunk in self.local_session.generate_response(user_input):
                yield chunk
        elif not self.use_local and self.openai_session:
            # This would need to be adapted based on OpenAI session interface
            # For now, we'll use the existing OpenAI session methods
            pass
    
    async def say_text(self, text: str) -> bool:
        """Say text using the current session."""
        if not self.current_session:
            return False
        
        if self.use_local and self.local_session:
            return await self.local_session.say_text(text)
        elif not self.use_local and self.openai_session:
            # Use existing OpenAI say functionality
            from .say import say
            await say(text)
            return True
        
        return False
    
    def get_health_status(self) -> Dict[str, Any]:
        """Get health status of the current session."""
        if not self.current_session:
            return {"status": "inactive"}
        
        if self.use_local and self.local_session:
            return {
                "status": "active",
                "mode": "local",
                "services": self.local_session.get_health_status()
            }
        elif not self.use_local and self.openai_session:
            return {
                "status": "active",
                "mode": "openai",
                "services": {"openai": True}
            }
        
        return {"status": "unknown"}
    
    def switch_to_local(self) -> bool:
        """Switch to local models if available."""
        if not self.use_local:
            self.use_local = True
            print("🔄 Switching to local models")
            return True
        return False
    
    def switch_to_openai(self) -> bool:
        """Switch to OpenAI if available."""
        if self.use_local:
            self.use_local = False
            print("🔄 Switching to OpenAI")
            return True
        return False
