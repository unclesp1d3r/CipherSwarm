# Phase 2: API Implementation

This phase outlines the full API architecture for CipherSwarm, including agent interaction, web UI functionality, and future TUI support. All endpoints must follow RESTful conventions and enforce authentication, validation, and input sanitation.

---

## 🔐 Agent API (High Priority)

The agent API is used by the agent to register, heartbeat, and report results. It is also used by the distributed CipherSwarm agents to obtain task assignments and submit results.

### Agent Authentication & Session Management

-   [x] Registration endpoint (`POST /api/v2/client/agents/register`)

    -   Accepts client signature, hostname, and agent type
    -   Returns token in format: `csa_<agent_id>_<token>`

-   [x] Heartbeat endpoint (`POST /api/v2/client/agents/heartbeat`)

    -   Must include headers:
        -   `Authorization: Bearer csa_<agent_id>_<token>`
    -   Rate limited to once every 15 seconds
    -   Tracks missed heartbeats and version drift

-   [x] State Management
    -   Accepts status updates (`pending`, `active`, `error`, `offline`)
    -   Fails if state not in enum
    -   Heartbeats update `last_seen_at`, `last_ipaddress`

### Attack Distribution

-   [x] Attack Configuration Endpoint

    -   Fetches full attack spec from server (mask, rules, etc.)
    -   Validates agent capability before sending (upon startup an agent performs a hashcat benchmark and reports the results, which are stored in the database, and used to validate which hash types an agent can crack. Campaigns for hash lists that the agent cannot crack are not assigned to the agent.)
    -   Note: Resource management fields (word_list_id, rule_list_id, mask_list_id, presigned URLs) will be fully supported in Phase 3. Endpoint and schema are forward-compatible.

-   [x] Resource Management

    -   Generates presigned URLs for agents
    -   Enforces hash verification pre-task

-   [x] Task Assignment

    -   One task per agent (enforced)
    -   Includes keyspace chunk (skip, limit fields now present)
    -   Includes hash file, dictionary IDs (deferred to Phase 3 resource management)

-   [x] Progress Tracking

    -   Agents send updates to `POST /api/v1/client/tasks/{id}/progress`
    -   Includes `progress_percent`, `keyspace_processed`

-   [x] Result Collection

    -   Results submitted via `POST /api/v1/client/tasks/{id}/result`
    -   Payload includes JSON structure of cracked hashes, metadata

-   [x] Legacy Agent API

    -   Maintains compatibility with legacy agent API (v1); see [swagger.json](../../swagger.json)
    -   Handles `GET /api/v1/agents/{id}`
    -   Handles `POST /api/v1/agents/{id}/benchmark`
    -   Handles `POST /api/v1/agents/{id}/error`
    -   Handles `POST /api/v1/agents/{id}/shutdown`

---

## 🧠 Web UI API

These API endpoints are used by the web UI to manage campaigns, attacks, and agents. They are not used by the agent and will require support for web-based user authentication using JWT tokens and OAuth for the purpose of supporting a HTMX-based UI.

These endpoints are to implement the backend endpoints to support the web UI that will be implemented in the next phase.

### Campaign Management

Campaigns are used to group attacks together. They are also used to track the progress of attacks and the agents that are running them. The Agent API does not understand campaigns, it only understands attacks, so this is exclusively a web UI concept.

-   [ ] CRUD Endpoints for campaigns
-   [ ] Add/remove attacks from campaigns
-   [ ] View campaign progress: active agents, total tasks.
    -   This will depend on the state machine for campaigns->attacks->tasks
    -   See item 2 of [Core Algorithm Implementation Guide](core_algorithm_implementation_guide.md) and the cursor rules for the state machine.
-   [ ] Aggregate stats
    -   See items 3 and 5 of [Core Algorithm Implementation Guide](core_algorithm_implementation_guide.md)

### Attack Management

Attack objects were previously implemented to support the Agent API, so this is a simple matter of adding the missing endpoints to create and manage them.

-   [ ] CRUD for attacks
    -   Creation of attacks will be done via the web UI and the endpoints will be used to validate the attack parameters and create the attack. The create endpoint should use the idiomatic FastAPI approach of using a Pydantic model to validate the request body and return the created attack object or a list of validation errors if the request body is invalid.
-   [ ] Assign rule/word/mask resources
    -   While the actual resource management functionality for loading and storing these resources in an S3-compatible object storage service is deferred to Phase 3, the endpoints to support this are implemented in this phase and stubbed out for future use.
    -   The file upload and download endpoints are provided via signed URLs from the S3-compatible object storage service, so this just tracks the resources and their linking to the attacks.
-   [ ] Validate attack configuration before queue
    -   The attacks will need to follow the restrictions by the agent's hashcat tool to ensure that the attack is valid and can be run. Validation should be done when the parameters are submitted to the endpoint.
    -   In addition to validating the attack parameters when the attack is submitted for creation, there should also be an endpoint to validate the attack parameters without the purpose of creating the attack so that the web form can provide feedback to the user about the validity of the attack parameters before the user clicks the submit button.
    -   If the attack parameters are invalid, the endpoint should return the list of invalid parameters and the reason they are invalid, following FastAPI's validation error format using Pydantic validation.
    -   If the attack parameters are valid, the validation endpoint should return the estimated time to completion of the attack and the estimated number of keyspace size that will be processed. See the [Core Algorithm Implementation Guide](core_algorithm_implementation_guide.md) section on keyspace estimation for more information.
-   [ ] Performance view (attack speed, task spread, agent usage)
    -   This will be a view of the attack progress and the performance of the agents that are running the attack.
    -   This will likely support both text representation and a graph representation.
-   [ ] Enable/disable attack live updates - this will support the Websocket endpoint for the HTMX-based web UI to receive live updates from the Web UI API.

### Agent Management (Web)

-   [ ] List/filter agents by state, version, label
    -   This will be a view of the agents that are currently registered with the Web UI.
-   [ ] View benchmarks and health
    -   This will be a view of the benchmarks and health of the agents that are currently registered with the Web UI.
-   [ ] Enable/disable agents manually
    -   This will be a view of the agents that are currently registered with the Web UI.
-   [ ] Manual requeue support
    -   This will be a view of the agents that are currently registered with the Web UI.
-   [ ] Presigned resource distribution testing
    -   This will be a view of the agents that are currently registered with the Web UI.

### Authentication and Profile Management

-   [ ] User model
-   [ ] Login endpoint
-   [ ] Logout endpoint
-   [ ] Profile endpoint
-   [ ] Update profile endpoint
-   [ ] Password change endpoint

---

## ⌨️ TUI API (Future-Focused)

These API endpoints are used by the TUI to manage campaigns, attacks, and agents. They are not used by the web UI.

These endpoints are to implement the backend endpoints to support the TUI that will be implemented in a later phase.

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

-   All agent endpoints must require valid `Authorization` headers
-   Enum values (`state`, `attack_mode`, etc.) must be validated and documented
-   Async endpoints should assume large payloads (resource presign, results)
-   Use modular routers: `client_router`, `web_router`, `tui_router`
-   Ensure all endpoints return JSON:API formatted responses with proper status codes
-   Begin with Agent API and Web Campaign endpoints before moving to TUI
