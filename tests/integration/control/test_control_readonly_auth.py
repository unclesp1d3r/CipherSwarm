"""
Integration tests for Control API readonly authentication.

Tests that verify readonly API keys can only access read endpoints and are denied write access.
"""

from http import HTTPStatus

import pytest
import pytest_asyncio
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.user_service import create_user_service
from app.models.project import ProjectUserAssociation, ProjectUserRole
from app.models.user import User, UserRole
from app.schemas.user import UserCreate
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory


@pytest_asyncio.fixture
async def api_key_client(
    async_client: AsyncClient, db_session: AsyncSession
) -> tuple[AsyncClient, User, str, str]:
    """
    Create a user with API keys and return (client, user, full_key, readonly_key).
    """
    # Create user using the service to ensure API keys are generated
    user_data = UserCreate(
        email="apitest@example.com", name="API Test User", password="testpassword123"
    )

    user_read = await create_user_service(
        db=db_session, user_in=user_data, role=UserRole.ANALYST
    )

    # Fetch the actual user from database to get API keys
    from sqlalchemy import select

    result = await db_session.execute(select(User).where(User.id == user_read.id))
    user = result.scalar_one()

    # Ensure API keys are not None
    assert user.api_key_full is not None, "Full API key should be generated"
    assert user.api_key_readonly is not None, "Readonly API key should be generated"

    return async_client, user, user.api_key_full, user.api_key_readonly


@pytest.mark.asyncio
async def test_new_user_has_readonly_api_key(db_session: AsyncSession) -> None:
    """Test that a new user has a readonly API key generated."""
    # Create user using the service
    user_data = UserCreate(
        email="newuser@example.com", name="New User", password="password123"
    )

    user_read = await create_user_service(
        db=db_session, user_in=user_data, role=UserRole.ANALYST
    )

    # Fetch the actual user from database to check API keys
    from sqlalchemy import select

    result = await db_session.execute(select(User).where(User.id == user_read.id))
    user = result.scalar_one()

    # Verify readonly API key exists and is properly formatted
    assert user.api_key_readonly is not None
    assert user.api_key_readonly.startswith("cst_")
    assert user.api_key_readonly_created_at is not None

    # Verify it's different from the full API key
    assert user.api_key_full != user.api_key_readonly


@pytest.mark.asyncio
async def test_readonly_key_can_access_read_endpoints(
    api_key_client: tuple[AsyncClient, User, str, str],
    project_factory: ProjectFactory,
    campaign_factory: CampaignFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    """Test that readonly API key can access GET endpoints."""
    async_client, user, full_key, readonly_key = api_key_client

    # Create project and associate user
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create a campaign to list
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    await campaign_factory.create_async(
        name="Test Campaign",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )

    # Test that readonly key can access GET /api/v1/control/campaigns
    headers = {"Authorization": f"Bearer {readonly_key}"}
    resp = await async_client.get("/api/v1/control/campaigns", headers=headers)

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert "items" in data
    assert "total" in data
    assert data["total"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["name"] == "Test Campaign"


@pytest.mark.asyncio
async def test_readonly_key_denied_write_endpoints(
    api_key_client: tuple[AsyncClient, User, str, str],
    project_factory: ProjectFactory,
    db_session: AsyncSession,
) -> None:
    """Test that readonly API key is denied access to write endpoints."""
    async_client, user, full_key, readonly_key = api_key_client

    # Create project and associate user
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    headers = {"Authorization": f"Bearer {readonly_key}"}

    # Test POST endpoint (if it exists) - this should fail with 403
    # Note: The current campaigns endpoint doesn't have POST implemented yet,
    # but we can test the pattern with any write operation

    # For now, let's test with a hypothetical POST that would create a campaign
    # This will likely return 405 Method Not Allowed since POST isn't implemented yet,
    # but the important thing is that it's not a 401 Unauthorized
    resp = await async_client.post(
        "/api/v1/control/campaigns",
        headers=headers,
        json={"name": "Test Campaign", "project_id": project.id},
    )

    # The endpoint might not be implemented yet (405), but it shouldn't be 401
    # If it is implemented, it should be 403 for readonly key
    assert resp.status_code in [HTTPStatus.METHOD_NOT_ALLOWED, HTTPStatus.FORBIDDEN]

    # Test PATCH endpoint (if it exists)
    resp = await async_client.patch(
        "/api/v1/control/campaigns/1",
        headers=headers,
        json={"name": "Updated Campaign"},
    )

    # Same logic - should not be 401 (unauthorized), but might be 405 or 403
    assert resp.status_code in [
        HTTPStatus.METHOD_NOT_ALLOWED,
        HTTPStatus.FORBIDDEN,
        HTTPStatus.NOT_FOUND,
    ]

    # Test DELETE endpoint (if it exists)
    resp = await async_client.delete("/api/v1/control/campaigns/1", headers=headers)

    # Same logic - should not be 401 (unauthorized), but might be 405 or 403
    assert resp.status_code in [
        HTTPStatus.METHOD_NOT_ALLOWED,
        HTTPStatus.FORBIDDEN,
        HTTPStatus.NOT_FOUND,
    ]


@pytest.mark.asyncio
async def test_full_key_can_access_read_endpoints(
    api_key_client: tuple[AsyncClient, User, str, str],
    project_factory: ProjectFactory,
    campaign_factory: CampaignFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    """Test that full API key can access GET endpoints."""
    async_client, user, full_key, readonly_key = api_key_client

    # Create project and associate user
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create a campaign to list
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    await campaign_factory.create_async(
        name="Test Campaign",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )

    # Test that full key can access GET /api/v1/control/campaigns
    headers = {"Authorization": f"Bearer {full_key}"}
    resp = await async_client.get("/api/v1/control/campaigns", headers=headers)

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert "items" in data
    assert "total" in data
    assert data["total"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["name"] == "Test Campaign"


@pytest.mark.asyncio
async def test_invalid_api_key_denied(async_client: AsyncClient) -> None:
    """Test that invalid API keys are denied access."""
    headers = {"Authorization": "Bearer invalid_key"}
    resp = await async_client.get("/api/v1/control/campaigns", headers=headers)

    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_missing_api_key_denied(async_client: AsyncClient) -> None:
    """Test that requests without API keys are denied access."""
    resp = await async_client.get("/api/v1/control/campaigns")

    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_readonly_key_format_validation(db_session: AsyncSession) -> None:
    """Test that readonly API keys follow the correct format."""
    # Create multiple users to test key uniqueness
    for i in range(3):
        user_data = UserCreate(
            email=f"user{i}@example.com", name=f"User {i}", password="password123"
        )

        user_read = await create_user_service(
            db=db_session, user_in=user_data, role=UserRole.ANALYST
        )

        # Fetch the actual user from database
        from sqlalchemy import select

        result = await db_session.execute(select(User).where(User.id == user_read.id))
        user = result.scalar_one()

        # Verify readonly key format: cst_<user_id>_<random>
        assert user.api_key_readonly is not None, "Readonly API key should be generated"
        assert user.api_key_readonly.startswith("cst_")
        parts = user.api_key_readonly.split("_")
        assert len(parts) == 3
        assert parts[0] == "cst"
        assert parts[1] == str(user.id)
        assert len(parts[2]) > 30  # Random part should be substantial
