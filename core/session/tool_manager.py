"""
Tool management for filtering and providing tools based on session mode.
"""

import os
from typing import Any

from ..base_tools import get_base_tools, get_user_tools
from ..config import CAMERA_HARDWARE, is_conversation_state_enabled
from ..logger import logger


class ToolManager:
    """Manages tool availability based on session mode."""

    def __init__(self):
        self._base_tools = None
        self._user_tools = None

    def get_tools(self, mode: str) -> list[dict[str, Any]]:
        """Get tools for given mode (guest/user)."""
        # Lazy load tools
        if self._base_tools is None:
            self._base_tools = get_base_tools()
        if self._user_tools is None:
            self._user_tools = get_user_tools()

        if mode == "guest":
            tools = list(self._base_tools)
        elif mode == "user":
            tools = list(self._base_tools) + list(self._user_tools)
        else:
            logger.warning(f"Unknown mode: {mode}, using base tools")
            tools = list(self._base_tools)

        if not is_conversation_state_enabled():
            tools = [t for t in tools if t.get("name") != "conversation_state"]

        camera_hardware = os.getenv("CAMERA_HARDWARE", CAMERA_HARDWARE).strip().lower()
        if camera_hardware not in {"rpi_camera", "usb_webcam"}:
            tools = [t for t in tools if t.get("name") != "describe_scene"]

        return tools

    def refresh_tools(self):
        """Refresh tool definitions (e.g., after song list changes)."""
        self._base_tools = get_base_tools()
        self._user_tools = get_user_tools()


# Singleton instance
tool_manager = ToolManager()
