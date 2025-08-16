---
inclusion: fileMatch
fileMatchPattern: [app/api/**/*.py]
---

# FastAPI Patterns and Best Practices for CipherSwarm

## API Structure and Organization

### Router Organization

- Each API interface has its own directory structure under `app/api/v1/endpoints/`
- Agent API: `app/api/v1/endpoints/agent/` (follows `contracts/v1_api_swagger.json` spec exactly)
- Web UI API: `app/api/v1/endpoints/web/` (powers Svelte frontend)
- Control API: `app/api/v1/endpoints/control/` (future CLI/TUI interface)
- Shared Infrastructure: `app/api/v1/endpoints/` (users.py, resources.py)

### Router File Naming

- Resource-based endpoints: `app/api/v1/endpoints/web/{resource}.py` (e.g., `hash_lists.py`, `campaigns.py`)
- Non-resource endpoints: grouped in `general.py` under each interface directory
- Each router file should have a clear prefix: `router = APIRouter(prefix="/{resource}", tags=["{Resource}"])`

## Request/Response Patterns

### Pagination

- All list endpoints MUST use `PaginatedResponse[T]` from [app/schemas/shared.py](mdc:CipherSwarm/app/schemas/shared.py)
- Standard pagination parameters: `page: int = 1`, `size: int = 20` (not skip/limit)
- Example:

```python
from app.schemas.shared import PaginatedResponse


@router.get("/")
async def list_items() -> PaginatedResponse[ItemOut]:
    return PaginatedResponse[ItemOut](
        items=items,
        total=total,
        page=page,
        page_size=size,
        search=search_term,
    )
```

### Authentication and Authorization

- All endpoints except `/auth/login` require authentication: `Depends(get_current_user)`
- Project-scoped endpoints use: `user_can_access_project_by_id(current_user, project_id)`
- Import pattern:

```python
from app.core.deps import get_current_user
from app.core.authz import user_can_access_project_by_id
from app.models.user import User
```

### Status Codes

- `201 Created` for successful resource creation
- `200 OK` for successful retrieval/update
- `204 No Content` for successful deletion or updates with no response body
- `404 Not Found` for missing resources with custom exceptions
- `422 Unprocessable Entity` for validation errors (automatic via Pydantic)

## Service Layer Pattern

### Service Organization

- All business logic goes in service functions under `app/core/services/`
- Service files named: `{resource}_service.py` (e.g., `hash_list_service.py`)
- Services handle database operations, validation, and business rules
- Endpoints should be thin wrappers around service calls

### Service Function Naming

- Create: `create_{resource}_service()`
- Read: `get_{resource}_service()`, `list_{resources}_service()`
- Update: `update_{resource}_service()`
- Delete: `delete_{resource}_service()`

### Error Handling in Services

- Define custom exceptions in service files or `app/core/exceptions.py`
- Example:

```python
class HashListNotFoundError(Exception):
    """Raised when a hash list is not found."""

    pass


async def get_hash_list_service(db: AsyncSession, hash_list_id: int) -> HashList:
    hash_list = await db.get(HashList, hash_list_id)
    if not hash_list:
        raise HashListNotFoundError(f"Hash list {hash_list_id} not found")
    return hash_list
```

## Schema Patterns

### Input/Output Schemas

- Input schemas: `{Resource}Create`, `{Resource}Update`
- Output schemas: `{Resource}Out`
- Update schemas: Use `{Resource}UpdateData` for service layer, optional fields
- Store schemas in `app/schemas/{resource}.py`

### Schema Validation

- Use Pydantic validators for complex validation logic
- Leverage `Field()` for constraints and documentation
- Example:

```python
class HashListCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    description: str | None = Field(None, max_length=1000)
    project_id: int = Field(..., gt=0)
    hash_type_id: int = Field(..., ge=0)
    is_unavailable: bool = False
```

## Database Patterns

### Session Management

- Use `Depends(get_db)` for database sessions
- Always use `AsyncSession` type hints
- Let dependency injection handle session lifecycle

### Query Patterns

- Use SQLAlchemy ORM methods: `db.get()`, `db.execute()`, `db.add()`, `db.commit()`
- For complex queries, use `select()` with proper joins and filters
- Always handle potential `None` returns from queries

### Pagination in Services

- Accept `skip: int` and `limit: int` parameters
- Return tuple of `(items: list[Model], total: int)`
- Use `offset()` and `limit()` for pagination, `count()` for totals

## Testing Patterns

### Test Organization

- Unit tests: `tests/unit/test_{resource}_service.py`
- Integration tests: `tests/integration/{interface}/test_{resource}.py`
- Use factories from `tests/factories/` for test data

### Factory Patterns

- Set `__set_relationships__ = False` to prevent auto-creation of related objects
- Use valid foreign key defaults (e.g., `hash_type_id = 0` for MD5)
- Explicitly provide required foreign keys in tests

### Authentication in Tests

- Use `authenticated_user_client` fixture for project-associated users
- Create `ProjectUserAssociation` records when testing project-scoped endpoints
- Don't rely on `authenticated_async_client` for project-scoped tests

## Import Organization

### Standard Import Order

1. Standard library imports
2. Third-party imports (FastAPI, Pydantic, SQLAlchemy)
3. Local app imports (models, schemas, services, deps)

### Common Import Patterns

```python
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.core.authz import user_can_access_project_by_id
from app.models.user import User
from app.schemas.shared import PaginatedResponse
```

## Error Handling

### Custom Exceptions

- Raise `HTTPException` for API-specific errors
- Use custom exception classes for domain logic
- Agent API v1: Follow legacy schema exactly (exempt from other error rules)
- All other APIs: Use FastAPI standard error format

### Validation Errors

- Let FastAPI handle Pydantic validation automatically
- Return structured error responses for complex validation
- Use `422 Unprocessable Entity` for validation failures

## Documentation

### Endpoint Documentation

- Always provide `summary` and `description` for endpoints
- Use clear, action-oriented summaries
- Include parameter descriptions in docstrings or `Field()` definitions

### Type Hints

- Use complete type hints for all function parameters and returns
- Prefer `str | None` over `Optional[str]` (Python 3.10+ union syntax)
- Use `Annotated` for dependency injection and validation
