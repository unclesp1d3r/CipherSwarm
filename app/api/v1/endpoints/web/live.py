"""
🧭 JSON API Refactor – CipherSwarm Web UI

Follow these rules for all endpoints in this file:
1. Must return Pydantic models as JSON (no TemplateResponse or render()).
2. Must use FastAPI parameter types: Query, Path, Body, Depends, etc.
3. Must not parse inputs manually — let FastAPI validate and raise 422s.
4. Must use dependency-injected context for auth/user/project state.
5. Must not include database logic — delegate to a service layer (e.g. campaign_service).
6. Must not contain HTMX, Jinja, or fragment-rendering logic.
7. Must annotate live-update triggers with: # WS_TRIGGER: <event description>
8. Must update test files to expect JSON (not HTML) and preserve test coverage.

📘 See canonical task list and instructions:
↪️  docs/v2_rewrite_implementation_plan/side_quests/web_api_json_tasks.md
"""

import asyncio

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter(prefix="/live", tags=["Live Feeds"])


# In-memory pub/sub for demo (replace with Redis or other in production)
class ConnectionManager:
    def __init__(self) -> None:
        self.active_connections: dict[str, list[WebSocket]] = {
            "campaigns": [],
            "agents": [],
            "toasts": [],
        }

    async def connect(self, feed: str, websocket: WebSocket) -> None:
        await websocket.accept()
        self.active_connections[feed].append(websocket)

    def disconnect(self, feed: str, websocket: WebSocket) -> None:
        self.active_connections[feed].remove(websocket)

    async def broadcast(self, feed: str, message: dict) -> None:
        for connection in self.active_connections[feed]:
            await connection.send_json(message)


manager = ConnectionManager()


# --- Auth stub (replace with real JWT/session check) ---
async def websocket_auth_check(_websocket: WebSocket) -> bool:
    # TODO: Implement real JWT/session check
    # For now, always accept
    return True


# --- WebSocket Endpoints ---


@router.websocket("/campaigns")
async def ws_campaigns(websocket: WebSocket) -> None:
    await websocket_auth_check(websocket)
    await manager.connect("campaigns", websocket)
    try:
        while True:  # noqa: ASYNC110
            # Wait for broadcast (in real impl, this would be triggered by ORM events)
            await asyncio.sleep(60)  # Keep alive
    except WebSocketDisconnect:
        manager.disconnect("campaigns", websocket)


@router.websocket("/agents")
async def ws_agents(websocket: WebSocket) -> None:
    await websocket_auth_check(websocket)
    await manager.connect("agents", websocket)
    try:
        while True:  # noqa: ASYNC110
            await asyncio.sleep(60)
    except WebSocketDisconnect:
        manager.disconnect("agents", websocket)


@router.websocket("/toasts")
async def ws_toasts(websocket: WebSocket) -> None:
    await websocket_auth_check(websocket)
    await manager.connect("toasts", websocket)
    try:
        while True:  # noqa: ASYNC110
            await asyncio.sleep(60)
    except WebSocketDisconnect:
        manager.disconnect("toasts", websocket)


# --- Example broadcast trigger (to be called from ORM/service events) ---
async def broadcast_campaign_update(campaign_id: int, html: str) -> None:
    message = {"type": "campaign_update", "id": campaign_id, "html": html}
    await manager.broadcast("campaigns", message)


async def broadcast_agent_update(agent_id: int, html: str) -> None:
    message = {"type": "agent_update", "id": agent_id, "html": html}
    await manager.broadcast("agents", message)


async def broadcast_toast(toast_html: str) -> None:
    message = {"type": "toast", "html": toast_html}
    await manager.broadcast("toasts", message)
