"""
Local LLM service client using Ollama API.
Replaces OpenAI Realtime API with local model inference.
"""

import asyncio
import json
import aiohttp
from typing import Dict, Any, AsyncGenerator, Optional
from .config import LOCAL_LLM_HOST, LOCAL_LLM_MODEL, LOCAL_LLM_PORT


class LocalLLMClient:
    """Client for interacting with local Ollama LLM service."""
    
    def __init__(self):
        self.base_url = f"http://{LOCAL_LLM_HOST}:{LOCAL_LLM_PORT}"
        self.model = LOCAL_LLM_MODEL
        self.session: Optional[aiohttp.ClientSession] = None
    
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
    
    async def generate_response(
        self, 
        messages: list[Dict[str, Any]], 
        tools: Optional[list[Dict[str, Any]]] = None,
        stream: bool = True
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Generate response from local LLM.
        
        Args:
            messages: List of conversation messages
            tools: Available function tools (optional)
            stream: Whether to stream the response
            
        Yields:
            Dict containing response data
        """
        if not self.session:
            raise RuntimeError("Client not initialized. Use async context manager.")
        
        payload = {
            "model": self.model,
            "messages": messages,
            "stream": stream,
            "options": {
                "temperature": 0.7,
                "top_p": 0.9,
                "max_tokens": 1000,
            }
        }
        
        if tools:
            payload["tools"] = tools
            payload["tool_choice"] = "auto"
        
        try:
            async with self.session.post(
                f"{self.base_url}/api/chat",
                json=payload,
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    yield {
                        "type": "error",
                        "error": {
                            "code": "local_llm_error",
                            "message": f"LLM service error: {response.status} - {error_text}"
                        }
                    }
                    return
                
                if stream:
                    async for line in response.content:
                        if line:
                            try:
                                data = json.loads(line.decode('utf-8'))
                                if data.get("done", False):
                                    yield {"type": "response.done"}
                                    break
                                
                                # Convert Ollama format to OpenAI-like format
                                if "message" in data:
                                    message = data["message"]
                                    if "content" in message:
                                        yield {
                                            "type": "response.text.delta",
                                            "delta": message["content"]
                                        }
                                    
                                    # Handle tool calls
                                    if "tool_calls" in message:
                                        for tool_call in message["tool_calls"]:
                                            yield {
                                                "type": "response.tool_call",
                                                "tool_call": {
                                                    "id": tool_call.get("id", ""),
                                                    "name": tool_call.get("function", {}).get("name", ""),
                                                    "arguments": tool_call.get("function", {}).get("arguments", "{}")
                                                }
                                            }
                            except json.JSONDecodeError:
                                continue
                else:
                    # Non-streaming response
                    data = await response.json()
                    if "message" in data:
                        message = data["message"]
                        yield {
                            "type": "response.text",
                            "content": message.get("content", "")
                        }
                        
                        if "tool_calls" in message:
                            for tool_call in message["tool_calls"]:
                                yield {
                                    "type": "response.tool_call",
                                    "tool_call": {
                                        "id": tool_call.get("id", ""),
                                        "name": tool_call.get("function", {}).get("name", ""),
                                        "arguments": tool_call.get("function", {}).get("arguments", "{}")
                                    }
                                }
                    
                    yield {"type": "response.done"}
                    
        except aiohttp.ClientError as e:
            yield {
                "type": "error",
                "error": {
                    "code": "connection_error",
                    "message": f"Failed to connect to local LLM: {str(e)}"
                }
            }
        except Exception as e:
            yield {
                "type": "error",
                "error": {
                    "code": "unknown_error",
                    "message": f"Unexpected error: {str(e)}"
                }
            }
    
    async def check_health(self) -> bool:
        """Check if the local LLM service is available."""
        try:
            if not self.session:
                async with aiohttp.ClientSession() as session:
                    async with session.get(f"{self.base_url}/api/tags") as response:
                        return response.status == 200
            else:
                async with self.session.get(f"{self.base_url}/api/tags") as response:
                    return response.status == 200
        except Exception:
            return False


# Global client instance
_llm_client: Optional[LocalLLMClient] = None


async def get_llm_client() -> LocalLLMClient:
    """Get or create the global LLM client."""
    global _llm_client
    if _llm_client is None:
        _llm_client = LocalLLMClient()
    return _llm_client


async def check_llm_health() -> bool:
    """Check if local LLM service is healthy."""
    async with LocalLLMClient() as client:
        return await client.check_health()
