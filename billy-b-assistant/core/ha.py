import os

import aiohttp


HA_URL = os.getenv("HA_URL")
HA_TOKEN = os.getenv("HA_TOKEN")
HA_LANG = os.getenv("HA_LANG", "en")


def ha_available():
    return bool(HA_URL and HA_TOKEN)


async def send_conversation_prompt(prompt: str) -> str | None:
    if not ha_available():
        print("⚠️ Home Assistant not configured.")
        return None

    url = f"{HA_URL.rstrip('/')}/api/conversation/process"
    headers = {
        "Authorization": f"Bearer {HA_TOKEN}",
        "Content-Type": "application/json",
    }

    payload = {"text": prompt, "language": HA_LANG}

    try:
        async with (
            aiohttp.ClientSession() as session,
            session.post(url, headers=headers, json=payload) as resp,
        ):
            if resp.status == 200:
                data = await resp.json()
                return data.get("response", "")
            print(f"⚠️ HA API returned HTTP {resp.status}")
            return None
    except Exception as e:
        print(f"❌ Error reaching Home Assistant API: {e}")
        return None
