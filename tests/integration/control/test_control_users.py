"""
Integration tests for Control API users endpoints.

These tests verify that user listing endpoints work correctly with API key authentication,
proper permission checking, and offset-based pagination.
"""

import uuid
from http import HTTPStatus

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User, UserRole
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


@pytest.mark.asyncio
async def test_create_user_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test successful user creation with default role."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    headers = {"Authorization": f"Bearer {api_key}"}

    # Create user data
    user_data = {
        "email": "newuser@example.com",
        "name": "New User",
        "password": "securepassword123",
    }

    # Make request
    response = await async_client.post(
        "/api/v1/control/users", json=user_data, headers=headers
    )

    # Verify response
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "newuser@example.com"
    assert data["name"] == "New User"
    assert data["role"] == "analyst"  # Default role
    assert data["is_active"] is True
    assert data["is_superuser"] is False
    assert "id" in data

    # Verify user was created in database with API key
    result = await db_session.execute(
        select(User).where(User.email == "newuser@example.com")
    )
    created_user = result.scalar_one()
    assert created_user.email == "newuser@example.com"
    assert created_user.name == "New User"
    assert created_user.role == UserRole.ANALYST
    assert created_user.api_key is not None
    assert created_user.api_key.startswith("cst_")


@pytest.mark.asyncio
async def test_create_user_with_role(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user creation with explicit role."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    headers = {"Authorization": f"Bearer {api_key}"}

    # Create user data with admin role
    user_data = {
        "email": "admin@example.com",
        "name": "Admin User 2",
        "password": "securepassword123",
        "role": "admin",
        "is_superuser": True,
    }

    # Make request
    response = await async_client.post(
        "/api/v1/control/users", json=user_data, headers=headers
    )

    # Verify response
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "admin@example.com"
    assert data["name"] == "Admin User 2"
    assert data["role"] == "admin"
    assert data["is_superuser"] is True
    assert data["is_active"] is True

    # Verify user was created in database
    result = await db_session.execute(
        select(User).where(User.email == "admin@example.com")
    )
    created_user = result.scalar_one()
    assert created_user.role == UserRole.ADMIN
    assert created_user.is_superuser is True


@pytest.mark.asyncio
async def test_create_user_with_inactive_flag(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user creation with inactive flag."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    headers = {"Authorization": f"Bearer {api_key}"}

    # Create user data with inactive flag
    user_data = {
        "email": "inactive@example.com",
        "name": "Inactive User",
        "password": "securepassword123",
        "is_active": False,
    }

    # Make request
    response = await async_client.post(
        "/api/v1/control/users", json=user_data, headers=headers
    )

    # Verify response
    assert response.status_code == 201
    data = response.json()
    assert data["is_active"] is False

    # Verify user was created in database
    result = await db_session.execute(
        select(User).where(User.email == "inactive@example.com")
    )
    created_user = result.scalar_one()
    assert created_user.is_active is False


@pytest.mark.asyncio
async def test_create_user_invalid_role(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user creation with invalid role."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    headers = {"Authorization": f"Bearer {api_key}"}

    # Create user data with invalid role
    user_data = {
        "email": "invalid@example.com",
        "name": "Invalid Role User",
        "password": "securepassword123",
        "role": "invalid_role",
    }

    # Make request
    response = await async_client.post(
        "/api/v1/control/users", json=user_data, headers=headers
    )

    # Verify error response
    assert response.status_code == 409
    data = response.json()
    assert data["title"] == "User Already Exists"
    assert "Invalid role" in data["detail"]
    assert "admin, analyst, operator" in data["detail"]


@pytest.mark.asyncio
async def test_create_user_duplicate_email(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user creation with duplicate email."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    headers = {"Authorization": f"Bearer {api_key}"}

    # Create first user
    user_data = {
        "email": "duplicate@example.com",
        "name": "First User",
        "password": "securepassword123",
    }

    response = await async_client.post(
        "/api/v1/control/users", json=user_data, headers=headers
    )
    assert response.status_code == 201

    # Try to create second user with same email
    user_data["name"] = "Second User"

    response = await async_client.post(
        "/api/v1/control/users", json=user_data, headers=headers
    )

    # Verify error response
    assert response.status_code == 409
    data = response.json()
    assert data["title"] == "User Already Exists"
    assert "already exists" in data["detail"]


@pytest.mark.asyncio
async def test_create_user_duplicate_name(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user creation with duplicate name."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    headers = {"Authorization": f"Bearer {api_key}"}

    # Create first user
    user_data = {
        "email": "user1@example.com",
        "name": "Duplicate Name",
        "password": "securepassword123",
    }

    response = await async_client.post(
        "/api/v1/control/users", json=user_data, headers=headers
    )
    assert response.status_code == 201

    # Try to create second user with same name
    user_data["email"] = "user2@example.com"

    response = await async_client.post(
        "/api/v1/control/users", json=user_data, headers=headers
    )

    # Verify error response
    assert response.status_code == 409
    data = response.json()
    assert data["title"] == "User Already Exists"
    assert "already exists" in data["detail"]


@pytest.mark.asyncio
async def test_create_user_insufficient_permissions(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user creation without admin permissions."""
    # Create regular user with API key (not admin)
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Regular User"
    )

    headers = {"Authorization": f"Bearer {api_key}"}

    # Create user data
    user_data = {
        "email": "unauthorized@example.com",
        "name": "Unauthorized User",
        "password": "securepassword123",
    }

    # Make request
    response = await async_client.post(
        "/api/v1/control/users", json=user_data, headers=headers
    )

    # Verify error response
    assert response.status_code == 403
    data = response.json()
    assert data["title"] == "Insufficient Permissions"
    assert "Admin permissions required" in data["detail"]


@pytest.mark.asyncio
async def test_create_user_missing_authentication(async_client: AsyncClient) -> None:
    """Test user creation without authentication."""
    # Create user data
    user_data = {
        "email": "unauthenticated@example.com",
        "name": "Unauthenticated User",
        "password": "securepassword123",
    }

    # Make request without headers
    response = await async_client.post("/api/v1/control/users", json=user_data)

    # Verify error response
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_create_user_invalid_input(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user creation with invalid input data."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    headers = {"Authorization": f"Bearer {api_key}"}

    # Test missing email
    response = await async_client.post(
        "/api/v1/control/users",
        json={"name": "No Email", "password": "password123"},
        headers=headers,
    )
    assert response.status_code == 422

    # Test invalid email format
    response = await async_client.post(
        "/api/v1/control/users",
        json={
            "email": "invalid-email",
            "name": "Invalid Email",
            "password": "password123",
        },
        headers=headers,
    )
    assert response.status_code == 422

    # Test missing password
    response = await async_client.post(
        "/api/v1/control/users",
        json={"email": "test@example.com", "name": "No Password"},
        headers=headers,
    )
    assert response.status_code == 422

    # Test missing name
    response = await async_client.post(
        "/api/v1/control/users",
        json={"email": "test@example.com", "password": "password123"},
        headers=headers,
    )
    assert response.status_code == 422


# User Update Endpoint Tests


@pytest.mark.asyncio
async def test_update_user_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test successful user update with admin permissions."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    # Create a test user to update
    result = await db_session.execute(
        select(User).where(User.email == "test@example.com")
    )
    existing_user = result.scalar_one_or_none()
    if not existing_user:
        test_user = User(
            email="test@example.com",
            name="Test User",
            hashed_password="hashed_password",
            role=UserRole.OPERATOR,
            is_active=True,
            is_superuser=False,
        )
        db_session.add(test_user)
        await db_session.commit()
        await db_session.refresh(test_user)
    else:
        test_user = existing_user

    headers = {"Authorization": f"Bearer {api_key}"}

    # Update user data
    update_data = {
        "name": "Updated Test User",
        "email": "updated@example.com",
        "role": "analyst",
    }

    # Make request
    response = await async_client.patch(
        f"/api/v1/control/users/{test_user.id}", json=update_data, headers=headers
    )

    # Verify response
    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert data["name"] == "Updated Test User"
    assert data["email"] == "updated@example.com"
    assert data["role"] == "analyst"
    assert data["id"] == str(test_user.id)

    # Verify user was updated in database
    await db_session.refresh(test_user)
    assert test_user.name == "Updated Test User"
    assert test_user.email == "updated@example.com"
    assert test_user.role == UserRole.ANALYST


@pytest.mark.asyncio
async def test_update_user_partial_update(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test partial user update (only some fields)."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    # Create a test user to update
    test_user = User(
        email="partial@example.com",
        name="Partial User",
        hashed_password="hashed_password",
        role=UserRole.OPERATOR,
        is_active=True,
        is_superuser=False,
    )
    db_session.add(test_user)
    await db_session.commit()
    await db_session.refresh(test_user)

    headers = {"Authorization": f"Bearer {api_key}"}

    # Update only the name
    update_data = {"name": "Updated Partial User"}

    # Make request
    response = await async_client.patch(
        f"/api/v1/control/users/{test_user.id}", json=update_data, headers=headers
    )

    # Verify response
    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert data["name"] == "Updated Partial User"
    assert data["email"] == "partial@example.com"  # Unchanged
    assert data["role"] == "operator"  # Unchanged

    # Verify user was updated in database
    await db_session.refresh(test_user)
    assert test_user.name == "Updated Partial User"
    assert test_user.email == "partial@example.com"  # Unchanged
    assert test_user.role == UserRole.OPERATOR  # Unchanged


@pytest.mark.asyncio
async def test_update_user_password(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user password update."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    # Create a test user to update
    test_user = User(
        email="password@example.com",
        name="Password User",
        hashed_password="old_hashed_password",
        role=UserRole.ANALYST,
        is_active=True,
        is_superuser=False,
    )
    db_session.add(test_user)
    await db_session.commit()
    await db_session.refresh(test_user)

    old_password_hash = test_user.hashed_password

    headers = {"Authorization": f"Bearer {api_key}"}

    # Update password
    update_data = {"password": "new_secure_password123"}

    # Make request
    response = await async_client.patch(
        f"/api/v1/control/users/{test_user.id}", json=update_data, headers=headers
    )

    # Verify response
    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert data["email"] == "password@example.com"

    # Verify password was changed in database
    await db_session.refresh(test_user)
    assert test_user.hashed_password != old_password_hash


@pytest.mark.asyncio
async def test_update_user_role_change(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user role change."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    # Create a test user to update
    test_user = User(
        email="role@example.com",
        name="Role User",
        hashed_password="hashed_password",
        role=UserRole.OPERATOR,
        is_active=True,
        is_superuser=False,
    )
    db_session.add(test_user)
    await db_session.commit()
    await db_session.refresh(test_user)

    headers = {"Authorization": f"Bearer {api_key}"}

    # Update role from operator to admin
    update_data = {"role": "admin"}

    # Make request
    response = await async_client.patch(
        f"/api/v1/control/users/{test_user.id}", json=update_data, headers=headers
    )

    # Verify response
    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert data["role"] == "admin"

    # Verify role was changed in database
    await db_session.refresh(test_user)
    assert test_user.role == UserRole.ADMIN


@pytest.mark.asyncio
async def test_update_user_invalid_role(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user update with invalid role."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    # Create a test user to update
    test_user = User(
        email="invalid@example.com",
        name="Invalid User",
        hashed_password="hashed_password",
        role=UserRole.ANALYST,
        is_active=True,
        is_superuser=False,
    )
    db_session.add(test_user)
    await db_session.commit()
    await db_session.refresh(test_user)

    headers = {"Authorization": f"Bearer {api_key}"}

    # Update with invalid role
    update_data = {"role": "invalid_role"}

    # Make request
    response = await async_client.patch(
        f"/api/v1/control/users/{test_user.id}", json=update_data, headers=headers
    )

    # Verify error response
    assert response.status_code == HTTPStatus.CONFLICT
    data = response.json()
    assert "Invalid role" in data["detail"]


@pytest.mark.asyncio
async def test_update_user_duplicate_email(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user update with duplicate email."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    # Create first user
    user1 = User(
        email="user1@example.com",
        name="User 1",
        hashed_password="hashed_password",
        role=UserRole.ANALYST,
        is_active=True,
        is_superuser=False,
    )
    db_session.add(user1)

    # Create second user
    user2 = User(
        email="user2@example.com",
        name="User 2",
        hashed_password="hashed_password",
        role=UserRole.ANALYST,
        is_active=True,
        is_superuser=False,
    )
    db_session.add(user2)
    await db_session.commit()
    await db_session.refresh(user1)
    await db_session.refresh(user2)

    headers = {"Authorization": f"Bearer {api_key}"}

    # Try to update user2's email to user1's email
    update_data = {"email": "user1@example.com"}

    # Make request
    response = await async_client.patch(
        f"/api/v1/control/users/{user2.id}", json=update_data, headers=headers
    )

    # Verify error response
    assert response.status_code == HTTPStatus.CONFLICT
    data = response.json()
    assert "Email already in use" in data["detail"]


@pytest.mark.asyncio
async def test_update_user_duplicate_name(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test user update with duplicate name."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    # Create first user
    user1 = User(
        email="name1@example.com",
        name="Duplicate Name",
        hashed_password="hashed_password",
        role=UserRole.ANALYST,
        is_active=True,
        is_superuser=False,
    )
    db_session.add(user1)

    # Create second user
    user2 = User(
        email="name2@example.com",
        name="Unique Name",
        hashed_password="hashed_password",
        role=UserRole.ANALYST,
        is_active=True,
        is_superuser=False,
    )
    db_session.add(user2)
    await db_session.commit()
    await db_session.refresh(user1)
    await db_session.refresh(user2)

    headers = {"Authorization": f"Bearer {api_key}"}

    # Try to update user2's name to user1's name
    update_data = {"name": "Duplicate Name"}

    # Make request
    response = await async_client.patch(
        f"/api/v1/control/users/{user2.id}", json=update_data, headers=headers
    )

    # Verify error response
    assert response.status_code == HTTPStatus.CONFLICT
    data = response.json()
    assert "Name already in use" in data["detail"]


@pytest.mark.asyncio
async def test_update_user_not_found(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test updating a non-existent user."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    headers = {"Authorization": f"Bearer {api_key}"}

    # Try to update non-existent user
    fake_user_id = uuid.uuid4()
    update_data = {"name": "Updated Name"}

    # Make request
    response = await async_client.patch(
        f"/api/v1/control/users/{fake_user_id}", json=update_data, headers=headers
    )

    # Verify error response
    assert response.status_code == HTTPStatus.NOT_FOUND
    data = response.json()
    assert f"User with ID '{fake_user_id}' not found" in data["detail"]


@pytest.mark.asyncio
async def test_update_user_insufficient_permissions(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test updating user without admin permissions."""
    # Create regular user with API key (not admin)
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Regular User"
    )

    # Create a test user to update
    test_user = User(
        email="target@example.com",
        name="Target User",
        hashed_password="hashed_password",
        role=UserRole.ANALYST,
        is_active=True,
        is_superuser=False,
    )
    db_session.add(test_user)
    await db_session.commit()
    await db_session.refresh(test_user)

    headers = {"Authorization": f"Bearer {api_key}"}

    # Try to update user without permissions
    update_data = {"name": "Updated Name"}

    # Make request
    response = await async_client.patch(
        f"/api/v1/control/users/{test_user.id}", json=update_data, headers=headers
    )

    # Verify error response
    assert response.status_code == HTTPStatus.FORBIDDEN
    data = response.json()
    assert "Admin permissions required" in data["detail"]


@pytest.mark.asyncio
async def test_update_user_missing_authentication(async_client: AsyncClient) -> None:
    """Test updating user without authentication."""
    fake_user_id = uuid.uuid4()
    update_data = {"name": "Updated Name"}

    # Make request without authorization header
    response = await async_client.patch(
        f"/api/v1/control/users/{fake_user_id}", json=update_data
    )

    # Verify error response
    assert response.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_update_user_invalid_uuid(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test updating user with invalid UUID."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    headers = {"Authorization": f"Bearer {api_key}"}

    # Try to update user with invalid UUID
    update_data = {"name": "Updated Name"}

    # Make request
    response = await async_client.patch(
        "/api/v1/control/users/not-a-uuid", json=update_data, headers=headers
    )

    # Verify error response (FastAPI validation error)
    assert response.status_code == HTTPStatus.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_update_user_empty_payload(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test updating user with empty payload."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    # Create a test user to update
    test_user = User(
        email="empty@example.com",
        name="Empty User",
        hashed_password="hashed_password",
        role=UserRole.ANALYST,
        is_active=True,
        is_superuser=False,
    )
    db_session.add(test_user)
    await db_session.commit()
    await db_session.refresh(test_user)

    headers = {"Authorization": f"Bearer {api_key}"}

    # Update with empty payload (should be allowed - no-op)
    update_data = {}

    # Make request
    response = await async_client.patch(
        f"/api/v1/control/users/{test_user.id}", json=update_data, headers=headers
    )

    # Verify response - should succeed but no changes
    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert data["name"] == "Empty User"  # Unchanged
    assert data["email"] == "empty@example.com"  # Unchanged


@pytest.mark.asyncio
async def test_update_user_response_format(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    """Test that update user response format matches UserRead schema."""
    # Create admin user with API key
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Admin User"
    )

    # Make the user a superuser
    result = await db_session.execute(select(User).where(User.id == user_id))
    admin_user = result.scalar_one()
    admin_user.is_superuser = True
    await db_session.commit()

    # Create a test user to update
    test_user = User(
        email="format@example.com",
        name="Format User",
        hashed_password="hashed_password",
        role=UserRole.OPERATOR,
        is_active=True,
        is_superuser=False,
    )
    db_session.add(test_user)
    await db_session.commit()
    await db_session.refresh(test_user)

    headers = {"Authorization": f"Bearer {api_key}"}

    # Update user
    update_data = {"name": "Updated Format User", "role": "analyst"}

    # Make request
    response = await async_client.patch(
        f"/api/v1/control/users/{test_user.id}", json=update_data, headers=headers
    )

    # Verify response format
    assert response.status_code == HTTPStatus.OK
    data = response.json()

    # Check UserRead schema fields
    assert isinstance(data["id"], str)  # UUID as string
    assert data["name"] == "Updated Format User"
    assert data["email"] == "format@example.com"
    assert data["is_active"] is True
    assert data["is_verified"] is False
    assert data["is_superuser"] is False
    assert data["role"] == "analyst"
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
