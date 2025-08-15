---
inclusion: always
---

# CipherSwarm Code Standards

## Core Principles

- **Service Layer Architecture**: All business logic must be in service functions under `app/core/services/`. API endpoints should be thin wrappers that delegate to services.
- **Logging**: Use `loguru` exclusively. Never use standard Python `logging`.
- **Caching**: Use `cashews` exclusively. No other caching mechanisms permitted.
- **API Versioning**: All public routes must be versioned (e.g., `/api/v1/...`).
- **Agent API v1 Compatibility**: Agent API v1 (`/api/v1/client/*`) must match `contracts/v1_api_swagger.json` exactly.

## FastAPI Standards

### Route Organization

- Agent API: `app/api/v1/endpoints/agent/` (legacy compatibility)
- Web UI API: `app/api/v1/endpoints/web/` (powers Svelte frontend)
- Control API: `app/api/v1/endpoints/control/` (future CLI interface)
- Shared: `app/api/v1/endpoints/` (users.py, resources.py)

### Route Definitions

```python
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.deps import get_current_user
from app.core.services.resource_service import create_resource_service

router = APIRouter(prefix="/resources", tags=["Resources"])


@router.post("/", status_code=status.HTTP_201_CREATED)
async def create_resource(
    data: ResourceCreate, current_user: User = Depends(get_current_user)
) -> ResourceOut:
    """Create a new resource."""
    try:
        return await create_resource_service(db, data, current_user)
    except ResourceNotFoundError:
        raise HTTPException(status_code=404, detail="Resource not found")
```

### Required Elements

- Return type annotations (not `response_model` in decorator)
- `summary` and `description` for OpenAPI docs
- Proper HTTP status codes using `fastapi.status` constants
- Tags defined in `APIRouter()`, not individual routes
- Pydantic models for all requests/responses

## Schema Standards

### Schema Organization

- Input: `{Resource}Create`, `{Resource}Update`
- Output: `{Resource}Out`
- Store in `app/schemas/{resource}.py`

### Schema Requirements

```python
from pydantic import BaseModel, Field


class ResourceCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255, description="Resource name")
    description: str | None = Field(None, max_length=1000)
    project_id: int = Field(..., gt=0)
```

- All fields need `Field()` with constraints and descriptions
- Enum fields must serialize as `.value`
- Use `example=...` in Field definitions for OpenAPI

## Service Layer Patterns

### Service Organization

- One service file per domain: `{resource}_service.py`
- Functions named: `{action}_{resource}_service()`
- CRUD: `create_`, `get_`, `list_`, `update_`, `delete_`

### Service Function Structure

```python
async def create_resource_service(
    db: AsyncSession, resource_data: ResourceCreate, current_user: User
) -> Resource:
    """Create a new resource."""
    # Validation
    if await _resource_exists(db, resource_data.name):
        raise ResourceExistsError("Resource already exists")

    # Business logic
    resource = Resource(**resource_data.model_dump())
    db.add(resource)
    await db.commit()
    await db.refresh(resource)
    return resource
```

## Error Handling

### Custom Exceptions

- Define in service files or `app/core/exceptions.py`
- Raise domain-specific exceptions in services
- Translate to HTTPException in endpoints

### Error Response Standards

- Agent API v1: Match legacy schema exactly
- All other APIs: Use FastAPI default `{"detail": "message"}`
- Control API: Use RFC9457 Problem Details format
- Never expose internal errors or stack traces

## Authentication & Authorization

### Standard Dependencies

```python
from app.core.deps import get_current_user
from app.core.authz import user_can_access_project_by_id


@router.get("/{project_id}/resources")
async def list_resources(
    project_id: int, current_user: User = Depends(get_current_user)
):
    user_can_access_project_by_id(current_user, project_id)
    # ... rest of endpoint
```

## Database Patterns

### Session Management

- Use `Depends(get_db)` for database sessions
- Always use `AsyncSession` type hints
- Services accept session as first parameter

### Query Patterns

```python
# Simple get
async def get_resource_service(db: AsyncSession, resource_id: int) -> Resource:
    resource = await db.get(Resource, resource_id)
    if not resource:
        raise ResourceNotFoundError(f"Resource {resource_id} not found")
    return resource


# Pagination
async def list_resources_service(
    db: AsyncSession, skip: int = 0, limit: int = 20
) -> tuple[list[Resource], int]:
    query = select(Resource).offset(skip).limit(limit)
    result = await db.execute(query)
    items = result.scalars().all()

    count_query = select(func.count(Resource.id))
    total = await db.scalar(count_query)

    return list(items), total or 0
```

## Background Tasks

### Task Organization

- Scheduled jobs: `app/core/jobs/` (e.g., `daily_cleanup_job.py`)
- User-triggered: `app/core/tasks/` (e.g., `dispatch_tasks.py`)
- Use `FastAPI.BackgroundTasks` or `asyncio.create_task`

### Task Requirements

- Must be idempotent and restartable
- Include proper error handling and logging
- Never block the main event loop
- Include unit and integration tests

## Testing Standards

### Test Organization

- Unit tests: `tests/unit/test_{resource}_service.py`
- Integration tests: `tests/integration/{interface}/test_{resource}.py`
- Use factories from `tests/factories/`

### Test Requirements

- Cover happy path, validation errors, auth failures, not found cases
- Use `status_code` assertions before accessing response bodies
- Mock external dependencies in unit tests
- Use real database in integration tests
