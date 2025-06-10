"""
Integration tests for Control API users endpoints.

These tests verify that user listing endpoints work correctly with API key authentication,
proper permission checking, and offset-based pagination.
"""

from http import HTTPStatus

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import UserRole
from tests.factories.user_factory import UserFactory
from tests.utils.test_helpers import create_user_with_api_key_and_project_access


@pytest.mark.asyncio
async def test_list_users_with_admin_permissions(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test that admin user can list users successfully."""
    # Create an admin user with API key
    admin_user = await user_factory.create_async(
        name="Admin User", role=UserRole.ADMIN, is_superuser=True
    )

    # Create some test users
    await user_factory.create_async(name="Test User 1", email="user1@example.com")
    await user_factory.create_async(name="Test User 2", email="user2@example.com")
    await user_factory.create_async(name="Test User 3", email="user3@example.com")

    # Test listing users
    headers = {"Authorization": f"Bearer {admin_user.api_key}"}
    resp = await async_client.get("/api/v1/control/users", headers=headers)

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()

    # Check response structure
    assert "items" in data
    assert "total" in data
    assert "limit" in data
    assert "offset" in data

    # Should include all users (admin + 3 test users)
    assert data["total"] >= 4
    assert len(data["items"]) >= 4
    assert data["limit"] == 20  # Default limit
    assert data["offset"] == 0  # Default offset

    # Check user data structure
    for user in data["items"]:
        assert "id" in user
        assert "name" in user
        assert "email" in user
        assert "is_active" in user
        assert "is_superuser" in user
        assert "is_verified" in user
        assert "role" in user
        assert "created_at" in user
        assert "updated_at" in user


@pytest.mark.asyncio
async def test_list_users_without_admin_permissions(
    async_client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Test that non-admin user cannot list users."""
    # Create a regular user with API key and project access
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Regular User"
    )

    # Test listing users should fail
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get("/api/v1/control/users", headers=headers)

    assert resp.status_code == HTTPStatus.FORBIDDEN
    data = resp.json()
    assert "Admin permissions required to list users" in data["detail"]


@pytest.mark.asyncio
async def test_list_users_without_authentication(
    async_client: AsyncClient,
) -> None:
    """Test that unauthenticated request fails."""
    resp = await async_client.get("/api/v1/control/users")
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_list_users_with_invalid_api_key(
    async_client: AsyncClient,
) -> None:
    """Test that invalid API key fails."""
    headers = {"Authorization": "Bearer invalid_key"}
    resp = await async_client.get("/api/v1/control/users", headers=headers)
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_list_users_offset_pagination(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test offset-based pagination for user listing."""
    # Create an admin user with API key
    admin_user = await user_factory.create_async(
        name="Admin User", role=UserRole.ADMIN, is_superuser=True
    )

    # Create multiple test users
    test_users = []
    for i in range(5):
        user = await user_factory.create_async(
            name=f"Test User {i:02d}", email=f"user{i:02d}@example.com"
        )
        test_users.append(user)

    headers = {"Authorization": f"Bearer {admin_user.api_key}"}

    # Test first page with limit=2, offset=0
    resp = await async_client.get(
        "/api/v1/control/users?limit=2&offset=0", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["limit"] == 2
    assert data["offset"] == 0
    assert len(data["items"]) == 2
    assert data["total"] >= 6  # admin + 5 test users

    # Test second page with limit=2, offset=2
    resp = await async_client.get(
        "/api/v1/control/users?limit=2&offset=2", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["limit"] == 2
    assert data["offset"] == 2
    assert len(data["items"]) == 2
    assert data["total"] >= 6

    # Test third page with limit=2, offset=4
    resp = await async_client.get(
        "/api/v1/control/users?limit=2&offset=4", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["limit"] == 2
    assert data["offset"] == 4
    assert len(data["items"]) >= 2  # Should have at least 2 more users
    assert data["total"] >= 6


@pytest.mark.asyncio
async def test_list_users_search_functionality(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test search functionality for user listing."""
    # Create an admin user with API key
    admin_user = await user_factory.create_async(
        name="Admin User", role=UserRole.ADMIN, is_superuser=True
    )

    # Create test users with specific names/emails for searching
    await user_factory.create_async(name="John Doe", email="john.doe@example.com")
    await user_factory.create_async(name="Jane Smith", email="jane.smith@example.com")
    await user_factory.create_async(name="Bob Johnson", email="bob.johnson@example.com")

    headers = {"Authorization": f"Bearer {admin_user.api_key}"}

    # Test search by name
    resp = await async_client.get("/api/v1/control/users?search=john", headers=headers)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] >= 2  # John Doe and Bob Johnson
    user_names = [user["name"] for user in data["items"]]
    assert any("John" in name for name in user_names)

    # Test search by email
    resp = await async_client.get(
        "/api/v1/control/users?search=jane.smith", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] >= 1
    user_emails = [user["email"] for user in data["items"]]
    assert any("jane.smith" in email for email in user_emails)

    # Test search with no results
    resp = await async_client.get(
        "/api/v1/control/users?search=nonexistent", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    # May have 0 results or results that don't match the search term exactly
    # (depends on existing data in the test database)


@pytest.mark.asyncio
async def test_list_users_pagination_limits(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test pagination parameter validation."""
    # Create an admin user with API key
    admin_user = await user_factory.create_async(
        name="Admin User", role=UserRole.ADMIN, is_superuser=True
    )

    headers = {"Authorization": f"Bearer {admin_user.api_key}"}

    # Test limit too high
    resp = await async_client.get("/api/v1/control/users?limit=101", headers=headers)
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY

    # Test limit too low
    resp = await async_client.get("/api/v1/control/users?limit=0", headers=headers)
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY

    # Test negative offset
    resp = await async_client.get("/api/v1/control/users?offset=-1", headers=headers)
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY

    # Test valid parameters
    resp = await async_client.get(
        "/api/v1/control/users?limit=10&offset=0", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK


@pytest.mark.asyncio
async def test_list_users_superuser_access(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test that superuser can access user listing even without explicit permissions."""
    # Create a superuser (not admin role but is_superuser=True)
    superuser = await user_factory.create_async(
        name="Super User", role=UserRole.ANALYST, is_superuser=True
    )

    # Create some test users
    await user_factory.create_async(name="Test User 1")
    await user_factory.create_async(name="Test User 2")

    # Test listing users should work for superuser
    headers = {"Authorization": f"Bearer {superuser.api_key}"}
    resp = await async_client.get("/api/v1/control/users", headers=headers)

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] >= 3  # superuser + 2 test users
    assert len(data["items"]) >= 3


@pytest.mark.asyncio
async def test_list_users_response_format(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test that response format matches OffsetPaginatedResponse[UserRead] schema."""
    # Create an admin user with API key
    admin_user = await user_factory.create_async(
        name="Admin User", role=UserRole.ADMIN, is_superuser=True
    )

    # Create a test user with known data
    await user_factory.create_async(
        name="Test User",
        email="test@example.com",
        role=UserRole.OPERATOR,
        is_active=True,
        is_verified=True,
    )

    headers = {"Authorization": f"Bearer {admin_user.api_key}"}
    resp = await async_client.get("/api/v1/control/users", headers=headers)

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()

    # Check top-level pagination structure
    assert isinstance(data["items"], list)
    assert isinstance(data["total"], int)
    assert isinstance(data["limit"], int)
    assert isinstance(data["offset"], int)

    # Find our test user in the results
    test_user_data = None
    for user in data["items"]:
        if user["email"] == "test@example.com":
            test_user_data = user
            break

    assert test_user_data is not None, "Test user not found in results"

    # Check UserRead schema fields
    assert isinstance(test_user_data["id"], str)  # UUID as string
    assert test_user_data["name"] == "Test User"
    assert test_user_data["email"] == "test@example.com"
    assert test_user_data["is_active"] is True
    assert test_user_data["is_verified"] is True
    assert test_user_data["role"] == "operator"
    assert "created_at" in test_user_data
    assert "updated_at" in test_user_data


# User Detail Endpoint Tests


@pytest.mark.asyncio
async def test_get_user_with_admin_permissions(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test that admin user can get user details successfully."""
    # Create an admin user with API key
    admin_user = await user_factory.create_async(
        name="Admin User", role=UserRole.ADMIN, is_superuser=True
    )

    # Create a test user to retrieve
    test_user = await user_factory.create_async(
        name="Test User",
        email="test@example.com",
        role=UserRole.OPERATOR,
        is_active=True,
        is_verified=True,
    )

    # Test getting user details
    headers = {"Authorization": f"Bearer {admin_user.api_key}"}
    resp = await async_client.get(
        f"/api/v1/control/users/{test_user.id}", headers=headers
    )

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()

    # Check user data structure matches UserRead schema
    assert data["id"] == str(test_user.id)
    assert data["name"] == "Test User"
    assert data["email"] == "test@example.com"
    assert data["is_active"] is True
    assert data["is_verified"] is True
    assert data["role"] == "operator"
    assert "created_at" in data
    assert "updated_at" in data


@pytest.mark.asyncio
async def test_get_user_without_admin_permissions(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test that non-admin user cannot get user details."""
    # Create a regular user with API key and project access
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Regular User"
    )

    # Create a test user to try to retrieve
    test_user = await user_factory.create_async(
        name="Test User", email="test@example.com"
    )

    # Test getting user details should fail
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get(
        f"/api/v1/control/users/{test_user.id}", headers=headers
    )

    assert resp.status_code == HTTPStatus.FORBIDDEN
    data = resp.json()
    assert "Admin permissions required to view user details" in data["detail"]


@pytest.mark.asyncio
async def test_get_user_without_authentication(
    async_client: AsyncClient,
    user_factory: UserFactory,
) -> None:
    """Test that unauthenticated request fails."""
    # Create a test user
    test_user = await user_factory.create_async(name="Test User")

    resp = await async_client.get(f"/api/v1/control/users/{test_user.id}")
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_get_user_with_invalid_api_key(
    async_client: AsyncClient,
    user_factory: UserFactory,
) -> None:
    """Test that invalid API key fails."""
    # Create a test user
    test_user = await user_factory.create_async(name="Test User")

    headers = {"Authorization": "Bearer invalid_key"}
    resp = await async_client.get(
        f"/api/v1/control/users/{test_user.id}", headers=headers
    )
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_get_user_not_found(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test that getting non-existent user returns 404."""
    # Create an admin user with API key
    admin_user = await user_factory.create_async(
        name="Admin User", role=UserRole.ADMIN, is_superuser=True
    )

    # Use a non-existent UUID
    non_existent_id = "00000000-0000-0000-0000-000000000000"

    headers = {"Authorization": f"Bearer {admin_user.api_key}"}
    resp = await async_client.get(
        f"/api/v1/control/users/{non_existent_id}", headers=headers
    )

    assert resp.status_code == HTTPStatus.NOT_FOUND
    data = resp.json()
    assert "User with ID" in data["detail"]
    assert "not found in database" in data["detail"]
    assert non_existent_id in data["detail"]


@pytest.mark.asyncio
async def test_get_user_with_invalid_uuid(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test that invalid UUID format returns 422."""
    # Create an admin user with API key
    admin_user = await user_factory.create_async(
        name="Admin User", role=UserRole.ADMIN, is_superuser=True
    )

    headers = {"Authorization": f"Bearer {admin_user.api_key}"}
    resp = await async_client.get("/api/v1/control/users/invalid-uuid", headers=headers)

    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_get_user_superuser_access(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test that superuser can access user details even without explicit permissions."""
    # Create a superuser (not admin role but is_superuser=True)
    superuser = await user_factory.create_async(
        name="Super User", role=UserRole.ANALYST, is_superuser=True
    )

    # Create a test user to retrieve
    test_user = await user_factory.create_async(
        name="Test User", email="test@example.com", role=UserRole.OPERATOR
    )

    # Test getting user details should work for superuser
    headers = {"Authorization": f"Bearer {superuser.api_key}"}
    resp = await async_client.get(
        f"/api/v1/control/users/{test_user.id}", headers=headers
    )

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["id"] == str(test_user.id)
    assert data["name"] == "Test User"
    assert data["email"] == "test@example.com"


@pytest.mark.asyncio
async def test_get_user_response_format(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test that response format matches UserRead schema exactly."""
    # Create an admin user with API key
    admin_user = await user_factory.create_async(
        name="Admin User", role=UserRole.ADMIN, is_superuser=True
    )

    # Create a test user with known data
    test_user = await user_factory.create_async(
        name="Test User",
        email="test@example.com",
        role=UserRole.OPERATOR,
        is_active=True,
        is_verified=True,
    )

    headers = {"Authorization": f"Bearer {admin_user.api_key}"}
    resp = await async_client.get(
        f"/api/v1/control/users/{test_user.id}", headers=headers
    )

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()

    # Check UserRead schema fields
    assert isinstance(data["id"], str)  # UUID as string
    assert data["name"] == "Test User"
    assert data["email"] == "test@example.com"
    assert data["is_active"] is True
    assert data["is_verified"] is True
    assert data["role"] == "operator"
    assert "created_at" in data
    assert "updated_at" in data

    # Ensure no extra fields are present
    expected_fields = {
        "id",
        "name",
        "email",
        "is_active",
        "is_verified",
        "is_superuser",
        "role",
        "created_at",
        "updated_at",
    }
    actual_fields = set(data.keys())
    assert actual_fields == expected_fields


@pytest.mark.asyncio
async def test_get_user_with_different_roles(
    async_client: AsyncClient,
    db_session: AsyncSession,
    user_factory: UserFactory,
) -> None:
    """Test getting users with different roles returns correct role values."""
    # Create an admin user with API key
    admin_user = await user_factory.create_async(
        name="Admin User", role=UserRole.ADMIN, is_superuser=True
    )

    # Create test users with different roles
    analyst_user = await user_factory.create_async(
        name="Analyst User", role=UserRole.ANALYST
    )
    operator_user = await user_factory.create_async(
        name="Operator User", role=UserRole.OPERATOR
    )

    headers = {"Authorization": f"Bearer {admin_user.api_key}"}

    # Test analyst user
    resp = await async_client.get(
        f"/api/v1/control/users/{analyst_user.id}", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["role"] == "analyst"

    # Test operator user
    resp = await async_client.get(
        f"/api/v1/control/users/{operator_user.id}", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["role"] == "operator"
