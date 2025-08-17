---

## inclusion: fileMatch fileMatchPattern: [app/core/services/\*\*/\*.py]

# Service Layer Architecture Patterns for CipherSwarm

## Service Layer Organization

### File Structure

- All services located in `app/core/services/`
- One service file per domain: `{resource}_service.py`
- Service files contain related business logic functions
- Import services in endpoints, not models directly

### Service Naming Conventions

- Service files: `{resource}_service.py` (e.g., `hash_list_service.py`, `campaign_service.py`)
- Service functions: `{action}_{resource}_service()` pattern
- CRUD operations: `create_`, `get_`, `list_`, `update_`, `delete_`
- Business operations: `{business_action}_{resource}_service()`

## Service Function Patterns

### Standard CRUD Operations

```python
# Create
async def create_hash_list_service(
    db: AsyncSession, hash_list_data: HashListCreate
) -> HashList:
    """Create a new hash list."""


# Read (single)
async def get_hash_list_service(db: AsyncSession, hash_list_id: int) -> HashList:
    """Get a hash list by ID."""


# Read (multiple with pagination)
async def list_hash_lists_service(
    db: AsyncSession,
    skip: int = 0,
    limit: int = 20,
    name_filter: str | None = None,
    project_id: int | None = None,
) -> tuple[list[HashList], int]:
    """List hash lists with pagination and filtering."""


# Update
async def update_hash_list_service(
    db: AsyncSession,
    hash_list_id: int,
    update_data: HashListUpdateData,
) -> HashList:
    """Update a hash list."""


# Delete
async def delete_hash_list_service(db: AsyncSession, hash_list_id: int) -> None:
    """Delete a hash list."""
```

### Business Logic Operations

```python
async def reorder_attacks_service(
    db: AsyncSession,
    campaign_id: int,
    attack_ids: list[int],
) -> list[Attack]:
    """Reorder attacks within a campaign."""


async def estimate_attack_keyspace_service(
    attack_data: AttackEstimateRequest,
) -> AttackEstimateResponse:
    """Estimate keyspace and complexity for an attack configuration."""
```

## Error Handling in Services

### Custom Exceptions

- Define domain-specific exceptions in service files
- Use descriptive exception names and messages
- Raise exceptions for business rule violations

```python
class HashListNotFoundError(Exception):
    """Raised when a hash list is not found."""

    pass


class HashListInUseError(Exception):
    """Raised when attempting to delete a hash list that is in use."""

    pass


async def delete_hash_list_service(db: AsyncSession, hash_list_id: int) -> None:
    hash_list = await get_hash_list_service(db, hash_list_id)

    # Check business rules
    if await _hash_list_has_active_campaigns(db, hash_list_id):
        raise HashListInUseError(
            f"Hash list {hash_list_id} is in use by active campaigns"
        )

    await db.delete(hash_list)
    await db.commit()
```

### Exception Translation

- Services raise domain exceptions
- Endpoints translate to HTTP exceptions
- Keep HTTP concerns out of service layer

```python
# In endpoint
try:
    await delete_hash_list_service(db, hash_list_id)
except HashListNotFoundError:
    raise HTTPException(status_code=404, detail="Hash list not found")
except HashListInUseError as e:
    raise HTTPException(status_code=409, detail=str(e))
```

## Data Access Patterns

### Database Session Usage

- Always accept `AsyncSession` as first parameter
- Use dependency injection for session management
- Let endpoints handle session lifecycle

### Query Patterns

```python
# Simple get by ID
async def get_hash_list_service(db: AsyncSession, hash_list_id: int) -> HashList:
    hash_list = await db.get(HashList, hash_list_id)
    if not hash_list:
        raise HashListNotFoundError(f"Hash list {hash_list_id} not found")
    return hash_list


# Complex query with filtering
async def list_hash_lists_service(
    db: AsyncSession,
    skip: int = 0,
    limit: int = 20,
    name_filter: str | None = None,
    project_id: int | None = None,
) -> tuple[list[HashList], int]:
    query = select(HashList)

    if name_filter:
        query = query.where(HashList.name.ilike(f"%{name_filter}%"))
    if project_id:
        query = query.where(HashList.project_id == project_id)

    # Get total count
    count_query = select(func.count()).select_from(query.subquery())
    total = await db.scalar(count_query)

    # Get paginated results
    query = query.offset(skip).limit(limit)
    result = await db.execute(query)
    items = result.scalars().all()

    return list(items), total or 0
```

### Transaction Management

- Services handle individual operations
- Let endpoints manage transaction boundaries for complex operations
- Use explicit commits when needed

## Input/Output Patterns

### Input Validation

- Accept Pydantic models for complex input
- Use primitive types for simple parameters
- Validate business rules in service layer

```python
async def create_hash_list_service(
    db: AsyncSession, hash_list_data: HashListCreate
) -> HashList:
    # Business validation
    if await _hash_list_name_exists(db, hash_list_data.name, hash_list_data.project_id):
        raise ValueError(
            f"Hash list name '{hash_list_data.name}' already exists in project"
        )

    hash_list = HashList(**hash_list_data.model_dump())
    db.add(hash_list)
    await db.commit()
    await db.refresh(hash_list)
    return hash_list
```

### Output Types

- Return domain models (SQLAlchemy models) from services
- Let endpoints handle serialization to response schemas
- Return tuples for operations that need multiple values

```python
# Return model
async def get_hash_list_service(db: AsyncSession, hash_list_id: int) -> HashList:
    pass


# Return tuple for pagination
async def list_hash_lists_service(
    db: AsyncSession, skip: int = 0, limit: int = 20
) -> tuple[list[HashList], int]:
    pass


# Return None for delete operations
async def delete_hash_list_service(db: AsyncSession, hash_list_id: int) -> None:
    pass
```

## Service Dependencies

### Service-to-Service Calls

- Services can call other services
- Import service functions directly
- Avoid circular dependencies

```python
from app.core.services.campaign_service import get_campaigns_by_hash_list_service


async def delete_hash_list_service(db: AsyncSession, hash_list_id: int) -> None:
    # Check if hash list is used in campaigns
    campaigns = await get_campaigns_by_hash_list_service(db, hash_list_id)
    if campaigns:
        raise HashListInUseError("Hash list is used in active campaigns")

    # Proceed with deletion
    hash_list = await get_hash_list_service(db, hash_list_id)
    await db.delete(hash_list)
    await db.commit()
```

### External Dependencies

- Keep external service calls in service layer
- Use dependency injection for external services
- Mock external dependencies in tests

## Business Logic Patterns

### Validation Logic

- Implement business rules in services
- Separate validation from data access
- Use helper functions for complex validation

```python
async def _validate_hash_list_deletion(db: AsyncSession, hash_list_id: int) -> None:
    """Validate that a hash list can be safely deleted."""
    # Check for active campaigns
    campaigns = await get_active_campaigns_by_hash_list(db, hash_list_id)
    if campaigns:
        raise HashListInUseError("Cannot delete hash list with active campaigns")

    # Check for running tasks
    tasks = await get_running_tasks_by_hash_list(db, hash_list_id)
    if tasks:
        raise HashListInUseError("Cannot delete hash list with running tasks")
```

### State Management

- Handle entity state transitions in services
- Validate state changes according to business rules
- Use enums for state values

```python
async def start_campaign_service(db: AsyncSession, campaign_id: int) -> Campaign:
    campaign = await get_campaign_service(db, campaign_id)

    if campaign.state != CampaignState.DRAFT:
        raise InvalidStateTransitionError(
            f"Cannot start campaign in state {campaign.state}"
        )

    campaign.state = CampaignState.ACTIVE
    campaign.started_at = datetime.utcnow()
    await db.commit()
    await db.refresh(campaign)

    return campaign
```

## Performance Considerations

### Query Optimization

- Use appropriate joins and eager loading
- Implement pagination for large result sets
- Cache expensive computations when appropriate

### Async Patterns

- Use async/await consistently
- Avoid blocking operations in async functions
- Use async database operations

## Testing Services

### Unit Testing

- Test services independently of endpoints
- Mock external dependencies
- Test both success and error paths

### Integration Testing

- Test services with real database
- Verify data persistence and retrieval
- Test complex business logic scenarios

```python
@pytest.mark.asyncio
async def test_create_hash_list_service_success(db_session):
    project = await ProjectFactory.create_async()
    hash_list_data = HashListCreate(
        name="Test Hash List",
        description="Test description",
        project_id=project.id,
        hash_type_id=0,
    )

    result = await create_hash_list_service(db_session, hash_list_data)

    assert result.name == "Test Hash List"
    assert result.project_id == project.id

    # Verify persistence
    saved = await get_hash_list_service(db_session, result.id)
    assert saved.name == "Test Hash List"
```
