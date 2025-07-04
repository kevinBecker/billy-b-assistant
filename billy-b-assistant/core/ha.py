import aiohttp
import os

HA_URL = os.getenv("HA_URL", "http://localhost:8123")
HA_TOKEN = os.getenv("HA_TOKEN")
HA_LANG = os.getenv("HA_LANG", "en")  # Default to English if not set

async def send_conversation_prompt(prompt: str) -> str:
    url = f"{HA_URL}/api/conversation/process"
    headers = {
        "Authorization": f"Bearer {HA_TOKEN}",
        "Content-Type": "application/json"
    }

    payload = {
        "text": prompt,
        "language": HA_LANG
    }

    async with aiohttp.ClientSession() as session:
        async with session.post(url, headers=headers, json=payload) as resp:
            if resp.status == 200:
                data = await resp.json()
                return data.get("response", "")
            else:
                print(f"⚠️ HA API error: {resp.status}")
                return None