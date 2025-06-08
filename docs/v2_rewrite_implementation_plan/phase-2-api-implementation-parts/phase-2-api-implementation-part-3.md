# ⌨️ Control API (`/api/v1/control/*`)

The Control API powers the CipherSwarm command-line (`csadmin`) and scripting interface. It exposes programmatic access to all major backend operations—campaigns, attacks, agents, hashlists, tasks, and stats—while enforcing scoped permissions based on the associated user and their API key. Unlike the Web UI API, this interface is designed purely for structured, machine-readable workflows.

## 📋 Implementation Context Added

This document has been enhanced with detailed implementation context for:

1. **🔐 API Key Authentication**: Complete database schema, dependency injection, and permission enforcement patterns
2. **📦 Content Negotiation**: MsgPack support implementation with fallback to JSON
3. **📁 Schema Compatibility**: Reuse existing `CampaignTemplate` and `AttackTemplate` from `app/schemas/shared.py`
4. **📊 Pagination & Filtering**: Leverage existing `PaginatedResponse[T]` schema with conversion utilities
5. **🚨 Error Handling**: RFC9457-compliant error responses with standardized exception types (see `https://github.com/NRWLDev/fastapi-problem`)
6. **🔄 State Management**: State validation and progress calculation based on core algorithm rules
7. **🏢 Project Scoping**: Multi-tenant access control and data filtering utilities

## 🔄 Service Layer Reuse Strategy

**Critical Implementation Principle**: The Control API should maximize reuse of existing service layer functions to minimize development effort and maintain consistency:

### Existing Services to Reuse

- `app/core/services/campaign_service.py` → All campaign operations
- `app/core/services/attack_service.py` → All attack operations  
- `app/core/services/agent_service.py` → All agent operations
- `app/core/services/resource_service.py` → Resource file management
- `app/core/services/health_service.py` → System health checks
- `app/core/services/dashboard_service.py` → System statistics

### Existing Schemas to Reuse

- `app/schemas/shared.py` → `PaginatedResponse[T]`, `CampaignTemplate`, `AttackTemplate`
- All existing Pydantic schemas for requests/responses

### Implementation Pattern

```python
# Control API endpoints should be thin wrappers around existing services
@router.get("/campaigns")
async def list_campaigns_control(
    offset: int = 0, 
    limit: int = 10,
    user: User = Depends(get_current_control_user),
    db: AsyncSession = Depends(get_db)
) -> PaginatedResponse[CampaignRead]:
    # 1. Convert pagination parameters
    # 2. Call existing service function
    # 3. Return in Control API format
    campaigns, total = await list_campaigns_service(db, skip=offset, limit=limit)
    page, page_size = control_to_web_pagination(offset, limit)
    return PaginatedResponse(items=campaigns, total=total, page=page, page_size=page_size)
```

All areas now include specific implementation code examples, database schema changes, and detailed task breakdowns focused on **maximizing reuse** of existing infrastructure.

---

## 🔐 Authentication

The Control API uses **persistent API keys** rather than JWT-based sessions.

### API Key Structure

- Every user is issued two API keys at account creation:

  - `api_key_full`: inherits all user permissions
  - `api_key_readonly`: restricts the user to GET-only operations

- All requests must send the API key via:

    ```http
    Authorization: Bearer <api_key>
    ```

- **API Key Format**: `cst_<user_id>_<random_string>` (similar to agent tokens but with `cst` prefix for "CipherSwarm TUI")

### Database Schema

Add the following fields to the `User` model:

```python
class User(Base):
    # ... existing fields ...
    api_key_full: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True, index=True)
    api_key_readonly: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True, index=True)
    api_key_full_created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    api_key_readonly_created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
```

### Authentication Dependency

Create a Control API authentication dependency:

```python
async def get_current_user_from_api_key(
    authorization: str = Header(None),
    db: AsyncSession = Depends(get_db)
) -> tuple[User, bool]:  # Returns (user, is_readonly)
    """
    Extract and validate API key from Authorization header.
    Returns tuple of (user, is_readonly_key).
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Missing or invalid Authorization header")
    
    api_key = authorization.replace("Bearer ", "")
    
    # Validate format: cst_<uuid>_<random>
    if not api_key.startswith("cst_"):
        raise HTTPException(401, "Invalid API key format")
    
    # Look up user by either api_key_full or api_key_readonly
    # Return (user, is_readonly) tuple
```

### Permission Enforcement

```python
def require_write_access(user_and_readonly: tuple[User, bool] = Depends(get_current_user_from_api_key)) -> User:
    """Dependency that ensures non-readonly access."""
    user, is_readonly = user_and_readonly
    if is_readonly:
        raise HTTPException(403, "Read-only API key cannot perform write operations")
    return user

def get_current_control_user(user_and_readonly: tuple[User, bool] = Depends(get_current_user_from_api_key)) -> User:
    """Dependency that returns current user for read operations."""
    user, _ = user_and_readonly
    return user
```

- Access is enforced at the router or dependency level depending on method and key scope.

### Implementation Tasks

- [ ] Add API key fields to User model and create migration `task_id:control.auth.user_model_fields`
- [ ] Add functionality to create the new keys in the database during user creation `task_id:control.auth.create_keys`
- [ ] Implement `get_current_user_from_api_key` dependency `task_id:control.auth.api_key_dependency`
- [ ] Implement `require_write_access` and `get_current_control_user` dependencies `task_id:control.auth.permission_dependencies`
- [ ] Add API key generation utility functions (format: `cst_<user_id>_<random>`) `task_id:control.auth.key_generation`
- [ ] Add a test to verify that a new user has a `api_key_readonly` key and that they can only access read endpoints `task_id:control.auth.readonly_key`
- [ ] Add a test to verify that a user with a `api_key_full` can access write endpoints `task_id:control.auth.full_key`
- [ ] Add functionality to allow a user to rotate their API keys `task_id:control.auth.rotate_keys`

---

## 📦 Response Format Strategy

- All responses must be **JSON** by default, using Pydantic v2 models
- Optional support for **MsgPack** via content negotiation:

    ```http
    Accept: application/msgpack
    ```

- Endpoints may return MsgPack selectively for:

  - Streaming agent telemetry
  - Live status updates
  - Large task diagnostics

### MsgPack Implementation

Create a content negotiation utility:

```python
from fastapi import Request
from fastapi.responses import JSONResponse
import msgpack

def get_response_format(request: Request) -> str:
    """Determine response format from Accept header."""
    accept_header = request.headers.get("Accept", "")
    if "application/msgpack" in accept_header:
        return "msgpack"
    return "json"

class MsgPackResponse(Response):
    """Custom response class for MsgPack encoding."""
    media_type = "application/msgpack"
    
    def render(self, content) -> bytes:
        return msgpack.packb(content, use_bin_type=True)

async def create_response(data, request: Request):
    """Create appropriate response based on Accept header."""
    format_type = get_response_format(request)
    if format_type == "msgpack":
        return MsgPackResponse(data)
    return JSONResponse(data)
```

### Implementation Task

- [ ] Add MsgPack content negotiation support to Control API endpoints `task_id:control.response.msgpack_support`

---

## 📁 Template Compatibility

- **Reuse Existing**: All export/import functionality must use the existing `CampaignTemplate` and `AttackTemplate` from `app/schemas/shared.py`
- No divergence is allowed between interfaces

### Existing Template Schemas

The Control API must reuse these existing schemas:

```python
from app.schemas.shared import CampaignTemplate, AttackTemplate

# Already implemented in shared.py:
# - CampaignTemplate: Complete campaign export/import structure
# - AttackTemplate: Attack configuration template with all modes
# - AttackTemplateRecordOut: Template record metadata
# - Schema version: "20250511" for compatibility tracking
```

### Reuse Existing Service Functions

Leverage existing template services:

```python
# Campaign export - reuse existing service
from app.core.services.campaign_service import export_campaign_template_service

async def control_export_campaign(campaign_id: int, db: AsyncSession) -> CampaignTemplate:
    return await export_campaign_template_service(campaign_id, db)

# Attack export - reuse existing service  
from app.core.services.attack_service import export_attack_template_service

async def control_export_attack(attack_id: int, db: AsyncSession) -> AttackTemplate:
    return await export_attack_template_service(attack_id, db)
```

### Implementation Tasks

- [ ] Verify Control API endpoints use existing template services `task_id:control.template.service_reuse`
- [ ] Add Control API template import functionality using existing schemas `task_id:control.template.import_functionality`

---

## 📊 Pagination

- **Reuse Existing**: Control API must use the existing `PaginatedResponse[T]` from `app/schemas/shared.py`
- Convert between Web UI pagination (page-based) and Control API pagination (offset-based):

```python
from app.schemas.shared import PaginatedResponse

def web_to_control_pagination(page: int, page_size: int) -> tuple[int, int]:
    """Convert page-based to offset-based pagination."""
    offset = (page - 1) * page_size
    limit = page_size
    return offset, limit

def control_to_web_pagination(offset: int, limit: int) -> tuple[int, int]:
    """Convert offset-based to page-based pagination."""
    page = (offset // limit) + 1
    page_size = limit
    return page, page_size
```

### Reuse Existing Service Functions

All Control API list endpoints should leverage existing service layer functions:

```python
# Campaign listing - reuse existing service
from app.core.services.campaign_service import list_campaigns_service

async def control_list_campaigns(
    offset: int = 0, 
    limit: int = 10,
    project_id: int | None = None,
    db: AsyncSession = Depends(get_db)
) -> PaginatedResponse[CampaignRead]:
    # Convert offset/limit to page/page_size for existing service
    page, page_size = control_to_web_pagination(offset, limit)
    campaigns, total = await list_campaigns_service(
        db=db, 
        skip=offset, 
        limit=limit, 
        project_id=project_id
    )
    return PaginatedResponse(
        items=campaigns,
        total=total,
        page=page,
        page_size=page_size
    )
```

### Implementation Tasks

- [ ] Create pagination conversion utilities `task_id:control.pagination.conversion_utils`
- [ ] Adapt existing service functions for Control API pagination `task_id:control.pagination.service_adaptation`

---

## 🎯 Campaign Control Endpoints

These endpoints allow creation, inspection, lifecycle control, and relaunching of campaigns. They mirror the Web UI capabilities, but return only machine-structured JSON.

Clients using `csadmin` or automated scripts must be able to create and manage campaigns via JSON payloads that follow the same schema used by the Web UI. Control API endpoints must support full campaign lifecycle management, including relaunching failed or modified attacks. Campaign metadata (e.g., name, visibility, active state) must be editable, but the server must reject any attempts to modify campaigns that are in a finalized state unless reactivation is explicitly requested. All validation logic (e.g., attached attacks, project membership, resource constraints) must match Web UI behavior to ensure parity.

### 🧩 Implementation Tasks

**Reuse Existing Services**: All endpoints should leverage existing service layer functions from `app/core/services/campaign_service.py`:

- [x] `GET /api/v1/control/campaigns` - List campaigns → Use `list_campaigns_service()` `task_id:control.campaign.list`
- [ ] `GET /api/v1/control/campaigns/{id}` - Campaign detail → Use `get_campaign_service()` `task_id:control.campaign.detail`
- [ ] `POST /api/v1/control/campaigns/` - Create campaign → Use `create_campaign_service()` `task_id:control.campaign.create`
- [ ] `PATCH /api/v1/control/campaigns/{id}` - Update campaign → Use `update_campaign_service()` `task_id:control.campaign.update`
- [ ] `POST /api/v1/control/campaigns/{id}/start` - Start campaign → Use `start_campaign_service()` `task_id:control.campaign.start`
- [ ] `POST /api/v1/control/campaigns/{id}/stop` - Stop campaign → Use `stop_campaign_service()` `task_id:control.campaign.stop`
- [ ] `POST /api/v1/control/campaigns/{id}/relaunch` - Relaunch campaign → Use `relaunch_campaign_service()` `task_id:control.campaign.relaunch`
- [ ] `DELETE /api/v1/control/campaigns/{id}` - Delete campaign → Use `delete_campaign_service()` `task_id:control.campaign.delete`
- [ ] `POST /api/v1/control/campaigns/{id}/export` - Export template → Use `export_campaign_template_service()` `task_id:control.campaign.export`
- [ ] `POST /api/v1/control/campaigns/import` - Import campaign from `CampaignTemplate` `task_id:control.campaign.import`

## 💥 Attack Control Endpoints

Attack management in the Control API mirrors the Web UI.

Clients (e.g., `csadmin`) must be able to create, inspect, and modify attacks using the same JSON template structure used by the Web UI. The API must prevent edits to attacks currently in `running` or `exhausted` state unless the client explicitly confirms that the attack should be reset and re-queued. All validation logic (e.g., for resource compatibility, hash mode constraints, or ephemeral inputs) must mirror the same rules enforced by the UI. This interface should also support attack preview or performance summary queries for tooling to make informed scheduling decisions. Endpoints support attack creation, validation, lifecycle management, performance review, and JSON export/import using the shared format.

### 🧩 Implementation Tasks

**Reuse Existing Services**: All endpoints should leverage existing service layer functions from `app/core/services/attack_service.py`:

- [ ] `GET /api/v1/control/attacks` - List attacks → Use `get_attack_list_service()` `task_id:control.attack.list`
- [ ] `GET /api/v1/control/attacks/{id}` - Attack detail → Use `get_attack_service()` `task_id:control.attack.detail`
- [ ] `POST /api/v1/control/attacks/` - Create attack → Use `create_attack_service()` `task_id:control.attack.create`
- [ ] `PATCH /api/v1/control/attacks/{id}` - Update attack → Use `update_attack_service()` `task_id:control.attack.update`
- [ ] `DELETE /api/v1/control/attacks/{id}` - Delete attack → Use `delete_attack_service()` `task_id:control.attack.delete`
- [ ] `POST /api/v1/control/attacks/{id}/validate` - Validate attack → Use `estimate_attack_keyspace_and_complexity()` `task_id:control.attack.validate`
- [ ] `GET /api/v1/control/attacks/{id}/performance` - Performance data → Use `get_attack_performance_summary_service()` `task_id:control.attack.performance`
- [ ] `POST /api/v1/control/attacks/{id}/export` - Export attack → Use `export_attack_template_service()` `task_id:control.attack.export`
- [ ] `POST /api/v1/control/attacks/import` - Import attack from `AttackTemplate` `task_id:control.attack.import`

## 👥 Agent Control Endpoints

These endpoints provide structured read and write access to the full set of agents registered with CipherSwarm. Agents are read-only to non-admin users, but visible to all project members. Admins can assign or restrict project access, adjust configuration, and retrieve real-time performance data.

### 🧩 Implementation Tasks

**Reuse Existing Services**: All endpoints should leverage existing service layer functions from `app/core/services/agent_service.py`:

- [ ] `GET /api/v1/control/agents` - List agents → Use `list_agents_service()` `task_id:control.agent.list`
- [ ] `GET /api/v1/control/agents/{id}` - Agent detail → Use `get_agent_by_id_service()` `task_id:control.agent.detail`
- [ ] `PATCH /api/v1/control/agents/{id}` - Update agent → Use `update_agent_service()` or `toggle_agent_enabled_service()` `task_id:control.agent.update`
- [ ] `PATCH /api/v1/control/agents/{id}/config` - Update config → Use `update_agent_config_service()` or `update_agent_hardware_service()` `task_id:control.agent.config`
- [ ] `GET /api/v1/control/agents/{id}/performance` - Performance data → Use `get_agent_device_performance_timeseries()` `task_id:control.agent.performance`
- [ ] `GET /api/v1/control/agents/{id}/errors` - Error logs → Use `get_agent_error_log_service()` `task_id:control.agent.errors`
- [ ] `POST /api/v1/control/agents/{id}/benchmark` - Trigger benchmark → Use `trigger_agent_benchmark_service()` `task_id:control.agent.benchmark`
- [ ] `GET /api/v1/control/agents/{id}/benchmarks` - Benchmark summary → Use `get_agent_benchmark_summary_service()` `task_id:control.agent.benchmark_summary`

## 📦 Task Control Endpoints

Task endpoints allow administrative-level inspection, state control, and lifecycle monitoring of individual cracking tasks. This includes agent-task assignments, requeue operations, error diagnostics, and performance tracking.

### 🧩 Implementation Tasks

**Reuse Existing Services**: All endpoints should leverage existing service layer functions from `app/core/services/task_service.py`:

- [ ] `GET /api/v1/control/tasks` - List tasks → Use existing task listing service (to be created) `task_id:control.task.list`
- [ ] `GET /api/v1/control/tasks/{id}` - Task detail → Use existing task detail service (to be created) `task_id:control.task.detail`
- [ ] `PATCH /api/v1/control/tasks/{id}/requeue` - Requeue task → Use existing task requeue service (to be created) `task_id:control.task.requeue`
- [ ] `POST /api/v1/control/tasks/{id}/cancel` - Cancel task → Use existing task cancellation service (to be created) `task_id:control.task.cancel`
- [ ] `GET /api/v1/control/tasks/{id}/logs` - Task logs → Create service for task log retrieval `task_id:control.task.logs`
- [ ] `GET /api/v1/control/tasks/{id}/performance` - Task performance → Create service for task performance metrics `task_id:control.task.performance`

## 📁 Resource File Control Endpoints

These endpoints allow users to upload, inspect, assign, and delete custom resource files: wordlists, rule files, and mask files. This supports scripted population of project resources, ephemeral file tracking, and file reuse across campaigns.

### 🧩 Implementation Tasks

**Reuse Existing Services**: All endpoints should leverage existing service layer functions from `app/core/services/resource_service.py`:

- [ ] `GET /api/v1/control/resources` - List resources → Use existing resource listing service (check `resource_service.py`) `task_id:control.resource.list`
- [ ] `GET /api/v1/control/resources/{id}` - Resource detail → Use existing resource detail service `task_id:control.resource.detail`
- [ ] `POST /api/v1/control/resources/` - Upload resource → Use existing resource upload service `task_id:control.resource.upload`
- [ ] `DELETE /api/v1/control/resources/{id}` - Delete resource → Use existing resource deletion service `task_id:control.resource.delete`
- [ ] `POST /api/v1/control/resources/{id}/assign` - Assign resource → Use existing resource assignment service `task_id:control.resource.assign`

## 🧂 HashList & HashItem Control Endpoints

These endpoints support importing, exporting, filtering, and inspecting hash lists and individual hash items. Export formats include plaintext-only wordlists, JtR `.pot` files, and CSV metadata dumps. Ingested files can be simple hash lines or CSV/JSON with structured metadata (e.g., source system, associated username, tags).

### 🧩 Implementation Tasks

**Reuse Existing Services**: All endpoints should leverage existing service layer functions (check for hash list services):

- [ ] `POST /api/v1/control/hashlists/import` - Import hashlists → Use existing hash import service `task_id:control.hashlist.import`
- [ ] `GET /api/v1/control/hashlists/{id}/cracked.txt` - Export plaintext → Create export service `task_id:control.hashlist.export_plaintext`
- [ ] `GET /api/v1/control/hashlists/{id}/cracked.pot` - Export pot file → Create export service `task_id:control.hashlist.export_potfile`
- [ ] `GET /api/v1/control/hashlists/{id}/cracked.csv` - Export CSV → Create export service `task_id:control.hashlist.export_csv`
- [ ] `GET /api/v1/control/hashitems` - List hash items → Create hash item listing service `task_id:control.hashitem.list_filtered`
- [ ] `GET /api/v1/control/hashitems/{id}` - Hash item detail → Create hash item detail service `task_id:control.hashitem.detail`

## 📊 Metrics & System Stats

These endpoints provide status introspection and control-plane telemetry for `csadmin` dashboards or monitoring tooling. They can be queried manually or polled from background health checks or TUI dashboards.

### 🧩 Implementation Tasks

**Reuse Existing Services**: All endpoints should leverage existing service layer functions:

- [ ] `GET /api/v1/control/status` - System health → Use `health_service.py` functions `task_id:control.system.status`
- [ ] `GET /api/v1/control/version` - API version → Create version service or use existing config `task_id:control.system.version`
- [ ] `GET /api/v1/control/queues` - Queue status → Create queue monitoring service `task_id:control.system.queue_depth`
- [ ] `GET /api/v1/control/stats` - System stats → Use `dashboard_service.py` for `DashboardSummary` schema `task_id:control.system.summary`

---

## 🧠 Implementation Notes for Skirmish

### 1. Authentication & Access Control

- All routes in `/api/v1/control/*` must require `Authorization: Bearer <api_key>`.
- Keys are attached to a user and must enforce full or read-only scopes.
- Access to data must respect **project scoping** — a user can only access agents, campaigns, and attacks from projects they're assigned to.

### Project Scoping Implementation

Create project access checking utilities:

```python
async def get_user_accessible_projects(user: User, db: AsyncSession) -> list[int]:
    """Get list of project IDs that the user has access to."""
    # Query user's project associations
    # Return list of project IDs

async def check_project_access(user: User, project_id: int, db: AsyncSession) -> bool:
    """Check if user has access to a specific project."""
    accessible_projects = await get_user_accessible_projects(user, db)
    return project_id in accessible_projects

def require_project_access(project_id: int):
    """Dependency factory to check project access."""
    async def _check_access(
        user: User = Depends(get_current_control_user),
        db: AsyncSession = Depends(get_db)
    ):
        if not await check_project_access(user, project_id, db):
            raise HTTPException(403, f"Access denied to project {project_id}")
        return user
    return _check_access
```

### Data Filtering by Project

All list endpoints must filter by user's accessible projects:

```python
async def filter_campaigns_by_project_access(
    query: Select,
    user: User,
    db: AsyncSession
) -> Select:
    """Add project filtering to campaign queries."""
    accessible_projects = await get_user_accessible_projects(user, db)
    return query.where(Campaign.project_id.in_(accessible_projects))
```

### Implementation Tasks

- [ ] Create project access utilities and dependencies `task_id:control.access.project_utilities`
- [ ] Add project filtering to all list endpoints `task_id:control.access.project_filtering`
- [ ] Add project access checks to detail endpoints `task_id:control.access.detail_checks`

### 2. Export/Import Format Consistency

- All export/import routes must use the exact same JSON schema used by the Web UI.
- Round-trip compatibility is mandatory.

### 3. MsgPack Handling

- Default to JSON for all endpoints.
- If `Accept: application/msgpack` is passed, encode output using MsgPack for supported endpoints (telemetry, performance).

### 4. Pagination

- Use offset-based pagination.
- Responses should include: `items`, `total`, `limit`, `offset`.

### 5. Error Handling

- All errors must return machine-parseable JSON in RFC9457 format.

```json
{
    "type": "https://example.com/probs/out-of-credit",
    "title": "You do not have enough credit.",
    "status": 403,
    "detail": "Your current balance is 30, but that costs 50.",
    "instance": "/account/12345/msgs/abc"
}
```

### RFC9457 Implementation

Create a consistent error handling system:

```python
# app/core/exceptions.py
class ControlAPIException(Exception):
    """Base exception for Control API with RFC9457 support."""
    def __init__(self, status_code: int, title: str, detail: str, type_url: str = None):
        self.status_code = status_code
        self.title = title
        self.detail = detail
        self.type_url = type_url or f"https://cipherswarm.local/problems/{status_code}"

# app/core/error_handlers.py
@app.exception_handler(ControlAPIException)
async def control_api_exception_handler(request: Request, exc: ControlAPIException):
    """Handle Control API exceptions with RFC9457 format."""
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "type": exc.type_url,
            "title": exc.title,
            "status": exc.status_code,
            "detail": exc.detail,
            "instance": str(request.url)
        },
        headers={"Content-Type": "application/problem+json"}
    )
```

### Standard Error Types

Define common error types:

```python
class InsufficientPermissionsError(ControlAPIException):
    def __init__(self, detail: str = "Read-only API key cannot perform write operations"):
        super().__init__(403, "Insufficient Permissions", detail)

class ResourceNotFoundError(ControlAPIException):
    def __init__(self, resource_type: str, resource_id: str):
        super().__init__(404, "Resource Not Found", f"{resource_type} with ID {resource_id} not found")

class ValidationError(ControlAPIException):
    def __init__(self, detail: str):
        super().__init__(422, "Validation Error", detail)
```

### Implementation Tasks

- [ ] Create RFC9457 error handling system for Control API `task_id:control.error.rfc9457_system`
- [ ] Define standard error types and messages `task_id:control.error.standard_types`
- [ ] Integrate error handlers with all Control API endpoints `task_id:control.error.integration`

### 6. Task Lifecycle Enforcement

- Task and attack lifecycle transitions must follow the state rules defined in `core_algorithm_implementation_guide.md`.

### State Machine Implementation

Reference the state transition rules from `core_algorithm_implementation_guide.md`:

```python
# Task States: pending -> running -> (completed|failed|cancelled)
# Attack States: pending -> running -> (completed|failed|paused)
# Campaign States: draft -> active -> (completed|archived)

class StateValidator:
    """Validates state transitions for tasks, attacks, and campaigns."""
    
    def can_transition_task(self, current_state: TaskStatus, new_state: TaskStatus) -> bool:
        """Check if task state transition is valid."""
        # Implement rules from core_algorithm_implementation_guide.md
        
    def can_transition_attack(self, current_state: AttackState, new_state: AttackState) -> bool:
        """Check if attack state transition is valid."""
        # Implement rules from core_algorithm_implementation_guide.md
        
    def can_transition_campaign(self, current_state: CampaignState, new_state: CampaignState) -> bool:
        """Check if campaign state transition is valid."""
        # Implement rules from core_algorithm_implementation_guide.md
```

### Progress Calculation

Implement keyspace-weighted progress from the core algorithm guide:

```python
def calculate_attack_progress(attack: Attack) -> float:
    """Calculate attack progress weighted by keyspace."""
    total_keyspace = sum(t.keyspace_total for t in attack.tasks)
    if total_keyspace == 0:
        return 0.0
    weighted_sum = sum((t.progress_percent / 100.0) * t.keyspace_total for t in attack.tasks)
    return (weighted_sum / total_keyspace) * 100.0

def calculate_campaign_progress(campaign: Campaign) -> float:
    """Calculate campaign progress from weighted attack progress."""
    if not campaign.attacks:
        return 0.0
    return sum(calculate_attack_progress(a) for a in campaign.attacks) / len(campaign.attacks)
```

### Implementation Tasks

- [ ] Create state validation utilities based on core algorithm guide `task_id:control.state.validation_utils`
- [ ] Implement progress calculation functions `task_id:control.state.progress_calculation`
- [ ] Add state transition enforcement to all lifecycle endpoints `task_id:control.state.transition_enforcement`

### 7. Read-Only Key Enforcement

- If the API key is read-only, block `POST`, `PATCH`, and `DELETE` methods with a 403 and explanatory error.

### Permission Checking Implementation

```python
def check_write_permission(request: Request, user_and_readonly: tuple[User, bool]):
    """Check if the current request requires write permissions."""
    user, is_readonly = user_and_readonly
    write_methods = {"POST", "PATCH", "PUT", "DELETE"}
    
    if request.method in write_methods and is_readonly:
        raise InsufficientPermissionsError(
            f"Read-only API key cannot perform {request.method} operations"
        )
    
    return user
```

### Implementation Task

- [ ] Add write permission enforcement to all Control API routers `task_id:control.auth.write_permission_enforcement`

---

### Documentation Updates

With the many changes to the API, we need to update the documentation to reflect the changes. Be sure to capture all the changes to the API in the documentation. The changes to be made are:

- [ ] Update the architecture documentation to reflect the changes. (found in `docs/architecture/*.md`)
- [ ] Update the API reference documentation to reflect the structure of the API and the endpoints that are available. (found in `docs/api/overview.md` and `docs/development/api-reference.md`)
- [ ] Update the user guide to reflect the changes. (found in `docs/user-guide/*.md`)
- [ ] Update the developer guide to reflect the changes. (found in `docs/development/*.md`)
- [ ] Update the getting started guide to reflect the changes. (found in `docs/getting-started/*.md`)
- [ ] Update the troubleshooting guide to reflect the changes. (found in `docs/user-guide/troubleshooting.md`)
- [ ] Update the FAQ to reflect the changes. (found in `docs/user-guide/faq.md`)

---
