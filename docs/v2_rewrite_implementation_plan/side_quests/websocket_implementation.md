# 🛳️ CipherSwarm WebSocket Live Update Implementation Task List

## Context

CipherSwarm's Web UI requires real-time updates for campaigns, attacks, agents, and cracked hash toasts. The current websocket endpoints are stubs—they do not broadcast real backend events. This document outlines the full set of tasks required to implement a production-grade, event-driven websocket system that pushes live updates to all connected clients via SvelteKit's websocket integration.

---

## Requirements

-   **Backend must broadcast updates** when Attacks, Tasks, Agents, or CrackResults change state.
-   **WebSocket endpoints** must push these updates to all connected clients, using a pub/sub backend (Redis recommended).
-   **Frontend (SvelteKit)** must receive and process these updates, triggering UI refreshes or swaps as needed.
-   **Security:** WebSocket connections must be authenticated (JWT/session).
-   **Scalability:** Solution must work across multiple app instances (not just in-memory).

---

## Task List

### 1. Pub/Sub Infrastructure

-   [ ] Add Redis as a dependency (if not present)
    -   Use `uv add redis` if not already installed.
    -   Update `pyproject.toml` and ensure Redis is running in dev/prod environments.
-   [ ] Configure Redis connection for pub/sub in FastAPI app
    -   Likely in `app/core/services/redis_pubsub.py` (create if missing) and `app/main.py` for startup/shutdown.
    -   Add config to `app/core/config.py` for Redis URL.
-   [ ] Create a pub/sub utility for publishing and subscribing to update channels (campaigns, agents, toasts)
    -   Implement in `app/core/services/redis_pubsub.py`.
    -   Define channels: `campaigns`, `agents`, `toasts`.

### 2. WebSocket Endpoint Refactor

-   [ ] Refactor `/api/v1/web/live/campaigns`, `/agents`, `/toasts` endpoints to:
    -   [ ] Subscribe to Redis pub/sub channels
    -   [ ] Forward messages to all connected clients in real time
    -   [ ] Handle disconnects and reconnections gracefully
    -   File: `app/api/v1/endpoints/web/live.py`
-   [ ] Implement proper JWT/session authentication for websocket connections
    -   Use dependencies from `app/core/auth.py` or similar.
    -   Update websocket handlers in `app/api/v1/endpoints/web/live.py`.

### 3. Backend Event Triggers

-   [ ] Add SQLAlchemy ORM event hooks or service-layer triggers for:
    -   [ ] Attack state/progress changes
    -   [ ] Task state/progress changes
    -   [ ] Agent state/heartbeat/errors
    -   [ ] CrackResult (cracked hash) submissions
    -   Likely in `app/core/services/attack_service.py`, `task_service.py`, `agent_service.py`, `crackresult_service.py` or via SQLAlchemy event listeners in `app/models/`.
-   [ ] On relevant event, publish a message to the appropriate Redis channel (with type, id, html/refresh_target)
    -   Use the pub/sub utility from `app/core/services/redis_pubsub.py`.
-   [ ] Render JSON API fragments for updates to include in the message payload
    -   Use Svelte components in `src/lib/partials/` or similar.

### 4. Message Format

-   [ ] Standardize message format:
    -   [ ] `{"type": <event_type>, "id": <entity_id>, "html": <rendered_fragment>, "refresh_target": <selector?>}`
    -   Define in `app/core/services/redis_pubsub.py` or a shared schema in `app/schemas/websocket.py`.
-   [ ] Document all supported event types and payloads
    -   Add to this file and/or `docs/api/`.

### 5. Frontend Integration

-   [ ] Ensure all relevant UI components use SvelteKit's websocket client to subscribe to the correct websocket endpoint
    -   Update Svelte components in `src/lib/` and `src/lib/partials/`.
-   [ ] On message, update the UI (swap/refresh fragment, show toast, etc.)
    -   Use SvelteKit websocket client and Svelte stores as needed in components.
-   [ ] Add fallback polling for browsers/environments without websocket support
    -   Implement in frontend JS or as a Svelte component.

### 6. Testing

-   [ ] Add integration tests for event-driven websocket updates (simulate backend event, assert client receives update)
    -   In `tests/integration/test_web_attacks.py` and similar files.
-   [ ] Add tests for authentication failures, reconnects, and error handling
    -   In `tests/integration/`.
-   [ ] Add load/scalability tests for multiple concurrent websocket clients
    -   In `tests/integration/` or a new `tests/load/`.

### 7. Documentation

-   [ ] Update developer docs with:
    -   [ ] Websocket architecture overview
    -   [ ] How to trigger/test live updates
    -   [ ] Security and scaling considerations
    -   Update `docs/v2_rewrite_implementation_plan/phase-2-api-implementation-parts/phase-2-api-implementation-part-2.md` and `docs/api/` as needed.

---

## Key Files and Entry Points

-   **WebSocket Endpoints:** `app/api/v1/endpoints/web/live.py`
-   **Pub/Sub Utility:** `app/core/services/redis_pubsub.py` (to be created)
-   **Event Hooks/Triggers:** `app/core/services/attack_service.py`, `task_service.py`, `agent_service.py`, `crackresult_service.py`, or SQLAlchemy event listeners in `app/models/`
-   **JSON Fragment Rendering:** `src/lib/partials/`, possibly `app/core/fragment_renderer.py`
-   **Frontend Integration:** `src/lib/`, `src/lib/partials/`, and custom JS if needed
-   **Testing:** `tests/integration/test_web_attacks.py`, other `tests/integration/` files
-   **Configuration:** `app/core/config.py` (Redis URL, thresholds)
-   **Authentication:** `app/core/auth.py` or similar
-   **Schemas:** `app/schemas/websocket.py` (message format)

---

**This checklist is the source of truth for implementing CipherSwarm's real-time websocket update system. Work down the list to deliver a robust, production-ready solution.**
