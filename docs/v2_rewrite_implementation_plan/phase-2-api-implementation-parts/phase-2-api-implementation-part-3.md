## ⌨️ Control API (`/api/v1/control/*`)

The Control API powers the CipherSwarm command-line (`csadmin`) and scripting interface. It exposes programmatic access to all major backend operations—campaigns, attacks, agents, hashlists, tasks, and stats—while enforcing scoped permissions based on the associated user and their API key. Unlike the Web UI API, this interface is designed purely for structured, machine-readable workflows.

---

### 🔐 Authentication

The Control API uses **persistent API keys** rather than JWT-based sessions.

-   Every user is issued two API keys at account creation:

    -   `api_key_full`: inherits all user permissions
    -   `api_key_readonly`: restricts the user to GET-only operations

-   All requests must send the API key via:

    ```http
    Authorization: Bearer <api_key>
    ```

-   Access is enforced at the router or dependency level depending on method and key scope.

---

### 📦 Response Format Strategy

-   All responses must be **JSON** by default, using Pydantic v2 models
-   Optional support for **MsgPack** via content negotiation:

    ```http
    Accept: application/msgpack
    ```

-   Endpoints may return MsgPack selectively for:

    -   Streaming agent telemetry
    -   Live status updates
    -   Large task diagnostics

---

### 📁 Template Compatibility

-   All export/import functionality (e.g., for Attacks and Campaigns) must use the **exact same schema** as the Web UI JSON templates
-   No divergence is allowed between interfaces

---

### 📊 Pagination

-   Control API follows an **offset-based** pagination model
-   Shared pagination schema:

    ```python
    class Pagination[T](BaseModel):
        items: List[T]
        total: int
        limit: int
        offset: int
    ```

-   Query parameters:

    -   `limit: int = Query(10, ge=1, le=100)`
    -   `offset: int = Query(0, ge=0)`

---

### 🎯 Campaign Control Endpoints

These endpoints allow creation, inspection, lifecycle control, and relaunching of campaigns. They mirror the Web UI capabilities, but return only machine-structured JSON.

Clients using `csadmin` or automated scripts must be able to create and manage campaigns via JSON payloads that follow the same schema used by the Web UI. Control API endpoints must support full campaign lifecycle management, including relaunching failed or modified attacks. Campaign metadata (e.g., name, visibility, active state) must be editable, but the server must reject any attempts to modify campaigns that are in a finalized state unless reactivation is explicitly requested. All validation logic (e.g., attached attacks, project membership, resource constraints) must match Web UI behavior to ensure parity.

#### 🧩 Implementation Tasks

-   [ ] `GET /api/v1/control/campaigns` - List campaigns (paginated, filterable) `task_id:control.campaign.list`
-   [ ] `GET /api/v1/control/campaigns/{id}` - Return full campaign detail (JSON only) `task_id:control.campaign.detail`
-   [ ] `POST /api/v1/control/campaigns/` - Create new campaign from user input or template `task_id:control.campaign.create`
-   [ ] `PATCH /api/v1/control/campaigns/{id}` - Edit campaign metadata or state `task_id:control.campaign.update`
-   [ ] `POST /api/v1/control/campaigns/{id}/start` - Begin campaign (same as Web UI) `task_id:control.campaign.start`
-   [ ] `POST /api/v1/control/campaigns/{id}/stop` - Halt campaign execution `task_id:control.campaign.stop`
-   [ ] `POST /api/v1/control/campaigns/{id}/relaunch` - Rerun all or failed attacks within a campaign `task_id:control.campaign.relaunch`
-   [ ] `DELETE /api/v1/control/campaigns/{id}` - Archive or permanently delete campaign `task_id:control.campaign.delete`
-   [ ] `POST /api/v1/control/campaigns/{id}/export` - Download JSON template (same schema as Web UI) `task_id:control.campaign.export`
-   [ ] `POST /api/v1/control/campaigns/import` - Upload and validate campaign JSON `task_id:control.campaign.import`

### 💥 Attack Control Endpoints

Attack management in the Control API mirrors the Web UI.

Clients (e.g., `csadmin`) must be able to create, inspect, and modify attacks using the same JSON template structure used by the Web UI. The API must prevent edits to attacks currently in `running` or `exhausted` state unless the client explicitly confirms that the attack should be reset and re-queued. All validation logic (e.g., for resource compatibility, hash mode constraints, or ephemeral inputs) must mirror the same rules enforced by the UI. This interface should also support attack preview or performance summary queries for tooling to make informed scheduling decisions. Endpoints support attack creation, validation, lifecycle management, performance review, and JSON export/import using the shared format.

#### 🧩 Implementation Tasks

-   [ ] `GET /api/v1/control/attacks` - List attacks (paginated, filterable) `task_id:control.attack.list`
-   [ ] `GET /api/v1/control/attacks/{id}` - Retrieve full attack config and state `task_id:control.attack.detail`
-   [ ] `POST /api/v1/control/attacks/` - Create attack from input or imported JSON `task_id:control.attack.create`
-   [ ] `PATCH /api/v1/control/attacks/{id}` - Edit attack settings `task_id:control.attack.update`
-   [ ] `DELETE /api/v1/control/attacks/{id}` - Remove attack from system `task_id:control.attack.delete`
-   [ ] `POST /api/v1/control/attacks/{id}/validate` - Return validation status and estimated keyspace `task_id:control.attack.validate`
-   [ ] `GET /api/v1/control/attacks/{id}/performance` - View performance data (agent guess rate, task spread) `task_id:control.attack.performance`
-   [ ] `POST /api/v1/control/attacks/{id}/export` - Export attack to JSON `task_id:control.attack.export`
-   [ ] `POST /api/v1/control/attacks/import` - Import attack JSON and validate `task_id:control.attack.import`

### 👥 Agent Control Endpoints

These endpoints provide structured read and write access to the full set of agents registered with CipherSwarm. Agents are read-only to non-admin users, but visible to all project members. Admins can assign or restrict project access, adjust configuration, and retrieve real-time performance data.

#### 🧩 Implementation Tasks

-   [ ] `GET /api/v1/control/agents` - List agents, filterable by state or project `task_id:control.agent.list`
-   [ ] `GET /api/v1/control/agents/{id}` - Return full agent detail and configuration `task_id:control.agent.detail`
-   [ ] `PATCH /api/v1/control/agents/{id}` - Update label, state, or project assignment `task_id:control.agent.update`
-   [ ] `PATCH /api/v1/control/agents/{id}/config` - Update backend device mask, update interval, or performance toggles `task_id:control.agent.config`
-   [ ] `GET /api/v1/control/agents/{id}/performance` - Stream or retrieve rolling performance metrics `task_id:control.agent.performance`
-   [ ] `GET /api/v1/control/agents/{id}/errors` - Retrieve latest agent-side error reports `task_id:control.agent.errors`
-   [ ] `POST /api/v1/control/agents/{id}/benchmark` - Trigger a fresh benchmark run for the agent `task_id:control.agent.benchmark`
-   [ ] `GET /api/v1/control/agents/{id}/benchmarks` - List current benchmark results by device/hash-type `task_id:control.agent.benchmark_summary`

### 📦 Task Control Endpoints

Task endpoints allow administrative-level inspection, state control, and lifecycle monitoring of individual cracking tasks. This includes agent-task assignments, requeue operations, error diagnostics, and performance tracking.

#### 🧩 Implementation Tasks

-   [ ] `GET /api/v1/control/tasks` - List all tasks (filterable by status, attack, agent) `task_id:control.task.list`
-   [ ] `GET /api/v1/control/tasks/{id}` - Retrieve full task record and recent status `task_id:control.task.detail`
-   [ ] `PATCH /api/v1/control/tasks/{id}/requeue` - Requeue task to restart execution `task_id:control.task.requeue`
-   [ ] `POST /api/v1/control/tasks/{id}/cancel` - Cancel pending or in-flight task `task_id:control.task.cancel`
-   [ ] `GET /api/v1/control/tasks/{id}/logs` - Retrieve recent execution logs `task_id:control.task.logs`
-   [ ] `GET /api/v1/control/tasks/{id}/performance` - Return performance and guess rate for this task `task_id:control.task.performance`

### 📁 Resource File Control Endpoints

These endpoints allow users to upload, inspect, assign, and delete custom resource files: wordlists, rule files, and mask files. This supports scripted population of project resources, ephemeral file tracking, and file reuse across campaigns.

#### 🧩 Implementation Tasks

-   [ ] `GET /api/v1/control/resources` - List available resource files, filterable by type/project `task_id:control.resource.list`
-   [ ] `GET /api/v1/control/resources/{id}` - View resource file metadata and usage references `task_id:control.resource.detail`
-   [ ] `POST /api/v1/control/resources/` - Upload new resource file (rules, masks, wordlist) `task_id:control.resource.upload`
-   [ ] `DELETE /api/v1/control/resources/{id}` - Delete unused resource file `task_id:control.resource.delete`
-   [ ] `POST /api/v1/control/resources/{id}/assign` - Assign file to a project or attack `task_id:control.resource.assign`

### 🧂 HashList & HashItem Control Endpoints

These endpoints support importing, exporting, filtering, and inspecting hash lists and individual hash items. Export formats include plaintext-only wordlists, JtR `.pot` files, and CSV metadata dumps. Ingested files can be simple hash lines or CSV/JSON with structured metadata (e.g., source system, associated username, tags).

#### 🧩 Implementation Tasks

-   [ ] `POST /api/v1/control/hashlists/import` - Upload uncracked hashes with metadata (JSON or CSV) `task_id:control.hashlist.import`
-   [ ] `GET /api/v1/control/hashlists/{id}/cracked.txt` - Export cracked plaintexts (newline-separated) `task_id:control.hashlist.export_plaintext`
-   [ ] `GET /api/v1/control/hashlists/{id}/cracked.pot` - Export John-compatible `.pot` file `task_id:control.hashlist.export_potfile`
-   [ ] `GET /api/v1/control/hashlists/{id}/cracked.csv` - Export full cracked CSV with metadata `task_id:control.hashlist.export_csv`
-   [ ] `GET /api/v1/control/hashitems` - List and filter hash items by hashlist, status, username, etc. `task_id:control.hashitem.list_filtered`
-   [ ] `GET /api/v1/control/hashitems/{id}` - Detail for a specific hash item (crack status, metadata, history) `task_id:control.hashitem.detail`

### 📊 Metrics & System Stats

These endpoints provide status introspection and control-plane telemetry for `csadmin` dashboards or monitoring tooling. They can be queried manually or polled from background health checks or TUI dashboards.

#### 🧩 Implementation Tasks

-   [ ] `GET /api/v1/control/status` - General system health check (returns status of Redis, DB, Agent queue) `task_id:control.system.status`
-   [ ] `GET /api/v1/control/version` - Return server + API version `task_id:control.system.version`
-   [ ] `GET /api/v1/control/queues` - Return current task queues + depth per agent/project `task_id:control.system.queue_depth`
-   [ ] `GET /api/v1/control/stats` - Summary totals (campaigns, cracked hashes, agents online) `task_id:control.system.summary`

---

### 🧠 Implementation Notes for Skirmish

#### 1. Authentication & Access Control

-   All routes in `/api/v1/control/*` must require `Authorization: Bearer <api_key>`.
-   Keys are attached to a user and must enforce full or read-only scopes.
-   Access to data must respect **project scoping** — a user can only access agents, campaigns, and attacks from projects they're assigned to.

#### 2. Export/Import Format Consistency

-   All export/import routes must use the exact same JSON schema used by the Web UI.
-   Round-trip compatibility is mandatory.

#### 3. MsgPack Handling

-   Default to JSON for all endpoints.
-   If `Accept: application/msgpack` is passed, encode output using MsgPack for supported endpoints (telemetry, performance).

#### 4. Pagination

-   Use offset-based pagination.
-   Responses should include: `items`, `total`, `limit`, `offset`.

#### 5. Error Handling

-   All errors must return machine-parseable JSON in RFC9457 format.

```json
{
    "type": "https://example.com/probs/out-of-credit",
    "title": "You do not have enough credit.",
    "status": 403,
    "detail": "Your current balance is 30, but that costs 50.",
    "instance": "/account/12345/msgs/abc"
}
```

#### 6. Task Lifecycle Enforcement

-   Task and attack lifecycle transitions must follow the state rules defined in `core_algorithm_implementation_guide.md`.

#### 7. Read-Only Key Enforcement

-   If the API key is read-only, block `POST`, `PATCH`, and `DELETE` methods with a 403 and explanatory error.
