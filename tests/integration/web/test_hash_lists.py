"""
Integration tests for hash list web endpoints.
"""

from http import HTTPStatus

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory
from tests.utils.hash_type_utils import get_or_create_hash_type


@pytest.mark.asyncio
async def test_create_hash_list_success(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
) -> None:
    """Test successful hash list creation."""
    # Set factory sessions
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]

    # Get authenticated client and user
    authenticated_async_client, user = authenticated_user_client

    # Create test data
    project = await ProjectFactory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Associate user with project
    from app.models.project import ProjectUserAssociation, ProjectUserRole

    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash list
    response = await authenticated_async_client.post(
        "/api/v1/web/hash_lists/",
        json={
            "name": "Test Hash List",
            "description": "A test hash list",
            "project_id": project.id,
            "hash_type_id": hash_type.id,
            "is_unavailable": False,
        },
    )

    assert response.status_code == 201
    data = response.json()
    assert data["name"] == "Test Hash List"
    assert data["description"] == "A test hash list"
    assert data["project_id"] == project.id
    assert data["hash_type_id"] == hash_type.id
    assert data["is_unavailable"] is False


@pytest.mark.asyncio
async def test_create_hash_list_validation_error(
    authenticated_async_client: AsyncClient,
) -> None:
    """Test hash list creation with validation errors."""
    response = await authenticated_async_client.post(
        "/api/v1/web/hash_lists/",
        json={
            "name": "",  # Invalid: empty name
            "project_id": -1,  # Invalid: negative ID
            "hash_type_id": -1,  # Invalid: negative ID
        },
    )

    assert response.status_code == HTTPStatus.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_create_hash_list_unauthorized(
    async_client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Test hash list creation without authentication."""
    # Set factory sessions
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]

    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")
    project = await ProjectFactory.create_async()
    response = await async_client.post(
        "/api/v1/web/hash_lists/",
        json={
            "name": "Test Hash List",
            "project_id": project.id,
            "hash_type_id": hash_type.id,
        },
    )

    assert response.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_list_hash_lists_success(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Test successful hash list listing."""
    # Set factory sessions
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    HashListFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]

    # Create test data
    project = await ProjectFactory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    await HashListFactory.create_async(
        name="Hash List 1",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )
    await HashListFactory.create_async(
        name="Hash List 2",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    response = await authenticated_async_client.get("/api/v1/web/hash_lists/")

    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert "items" in data
    assert "total" in data
    assert len(data["items"]) == 2


@pytest.mark.asyncio
async def test_list_hash_lists_with_pagination(
    authenticated_async_client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Test hash list listing with pagination."""
    # Set factory sessions
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    HashListFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]

    # Create test data
    project = await ProjectFactory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    for i in range(5):
        await HashListFactory.create_async(
            name=f"Hash List {i}",
            project_id=project.id,
            hash_type_id=hash_type.id,
        )

    response = await authenticated_async_client.get(
        "/api/v1/web/hash_lists/?page=2&size=2"
    )

    assert response.status_code == HTTPStatus.OK
    data = response.json()
    assert len(data["items"]) == 2
    assert data["total"] == 5
