# Phase 2: API Implementation

This phase outlines the full API architecture for CipherSwarm, including agent interaction, web UI functionality, and future TUI support. All endpoints must follow RESTful conventions and enforce authentication, validation, and input sanitation.

---

## 🔐 Agent API (High Priority)

### Agent Authentication & Session Management

-   [ ] Registration endpoint (`POST /api/v1/client/agents/register`)

    -   Accepts client signature, hostname, and agent type
    -   Returns token in format: `csa_<agent_id>_<token>`

-   [ ] Heartbeat endpoint (`POST /api/v1/client/agents/heartbeat`)

    -   Must include headers:
        -   `Authorization: Bearer csa_<agent_id>_<token>`
        -   `User-Agent: CipherSwarm-Agent/x.y.z`
    -   Rate limited to once every 15 seconds
    -   Tracks missed heartbeats and version drift

-   [ ] State Management
    -   Accepts status updates (`pending`, `active`, `error`, `offline`)
    -   Fails if state not in enum
    -   Heartbeats update `last_seen_at`, `last_ipaddress`

### Attack Distribution

-   [ ] Attack Configuration Endpoint

    -   Fetches full attack spec from server (mask, rules, etc.)
    -   Validates agent capability before sending

-   [ ] Resource Management

    -   Generates presigned URLs for agents
    -   Enforces hash verification pre-task

-   [ ] Task Assignment

    -   One task per agent
    -   Includes keyspace chunk, hash file, dictionary IDs

-   [ ] Progress Tracking

    -   Agents send updates to `POST /api/v1/client/tasks/{id}/progress`
    -   Includes `progress_percent`, `keyspace_processed`

-   [ ] Result Collection
    -   Results submitted via `POST /api/v1/client/tasks/{id}/result`
    -   Payload includes JSON structure of cracked hashes, metadata

---

## 🧠 Web UI API

### Campaign Management

-   [ ] CRUD Endpoints for campaigns
-   [ ] Attach/detach attacks to campaigns
-   [ ] View campaign progress: active agents, total tasks
-   [ ] Export results: `GET /api/v1/web/campaigns/{id}/export.csv`
-   [ ] Aggregate stats (use Redis or async cache job)

### Attack Management

-   [ ] CRUD for attacks
-   [ ] Assign rule/word/mask resources
-   [ ] Validate attack configuration before queue
-   [ ] Performance view (attack speed, task spread, agent usage)
-   [ ] Enable/disable attack live

### Agent Management (Web)

-   [ ] List/filter agents by state, version, label
-   [ ] View benchmarks and health
-   [ ] Enable/disable agents manually
-   [ ] Manual requeue support
-   [ ] Presigned resource distribution testing

---

## ⌨️ TUI API (Future-Focused)

### Core Implementation

-   [ ] Auth via API key: `cst_<user_id>_<token>`
-   [ ] CLI Token linked to specific user
-   [ ] Command format:

    -   `campaign list`
    -   `attack start <id>`
    -   `results export <id>`

-   [ ] Help & Command Reference
-   [ ] Structured response formatting
-   [ ] Error responses mapped to CLI-friendly messages

### Campaign Operations

-   [ ] Manage campaigns from CLI
-   [ ] Attach attacks, view progress
-   [ ] Output status and metadata
-   [ ] Support export to CSV or JSON
-   [ ] Minimal read/write scope enforcement

---

## ✅ Notes for Cursor

-   All agent endpoints must require valid `Authorization` and `User-Agent` headers
-   Enum values (`state`, `attack_mode`, etc.) must be validated and documented
-   Async endpoints should assume large payloads (resource presign, results)
-   Use modular routers: `client_router`, `web_router`, `tui_router`
-   Ensure all endpoints return JSON:API formatted responses with proper status codes
-   Begin with Agent API and Web Campaign endpoints before moving to TUI
