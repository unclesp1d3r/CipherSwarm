"""
Tests for Control API project endpoints.

These tests verify that project detail, update, and delete endpoints
properly check project access permissions.
"""

from http import HTTPStatus

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from tests.factories.project_factory import ProjectFactory
from tests.utils.test_helpers import create_user_with_api_key_and_project_access


@pytest.mark.asyncio
async def test_get_project_with_access(
    async_client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Test that user can access project detail when they have access."""
    # Create a user with access to a project using helper
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Test User", project_name="Test Project"
    )

    # Test accessing the project
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get(
        f"/api/v1/control/projects/{project_id}", headers=headers
    )

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["id"] == project_id
    assert data["name"] == "Test Project"


@pytest.mark.asyncio
async def test_get_project_without_access(
    api_key_client: tuple[AsyncClient, User, str],
    project_factory: ProjectFactory,
) -> None:
    """Test that user cannot access project detail when they don't have access."""
    async_client, user, api_key = api_key_client

    # Create a project but don't associate user with it
    project = await project_factory.create_async()

    # Test accessing the project should fail
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get(
        f"/api/v1/control/projects/{project.id}", headers=headers
    )

    assert resp.status_code == HTTPStatus.FORBIDDEN
    data = resp.json()
    assert (
        f"User 'API Test User' does not have access to project {project.id}"
        in data["detail"]
    )


@pytest.mark.asyncio
async def test_get_nonexistent_project(
    api_key_client: tuple[AsyncClient, User, str],
) -> None:
    """Test that accessing a nonexistent project returns 404."""
    async_client, user, api_key = api_key_client

    # Test accessing a nonexistent project
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get("/api/v1/control/projects/99999", headers=headers)

    assert (
        resp.status_code == HTTPStatus.NOT_FOUND
    )  # Now properly returns 404 for nonexistent projects


@pytest.mark.asyncio
async def test_update_project_with_access(
    api_key_client: tuple[AsyncClient, User, str],
    project_factory: ProjectFactory,
    db_session: AsyncSession,
) -> None:
    """Test that user can update project when they have access."""
    async_client, user, api_key = api_key_client

    # Create a user with access to a project using helper
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Test User", project_name="Test Project"
    )

    # Test updating the project
    headers = {"Authorization": f"Bearer {api_key}"}
    update_data = {"name": "Updated Project Name"}
    resp = await async_client.patch(
        f"/api/v1/control/projects/{project_id}", headers=headers, json=update_data
    )

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["name"] == "Updated Project Name"


@pytest.mark.asyncio
async def test_update_project_without_access(
    api_key_client: tuple[AsyncClient, User, str],
    project_factory: ProjectFactory,
) -> None:
    """Test that user cannot update project when they don't have access."""
    async_client, user, api_key = api_key_client

    # Create a project but don't associate user with it
    project = await project_factory.create_async()

    # Test updating the project should fail
    headers = {"Authorization": f"Bearer {api_key}"}
    update_data = {"name": "Updated Project Name"}
    resp = await async_client.patch(
        f"/api/v1/control/projects/{project.id}", headers=headers, json=update_data
    )

    assert resp.status_code == HTTPStatus.FORBIDDEN
    data = resp.json()
    assert (
        f"User 'API Test User' does not have access to project {project.id}"
        in data["detail"]
    )


@pytest.mark.asyncio
async def test_delete_project_with_access(
    api_key_client: tuple[AsyncClient, User, str],
    db_session: AsyncSession,
) -> None:
    """Test that user can delete project when they have access."""
    async_client, user, api_key = api_key_client

    # Create a user with access to a project using helper
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Test User", project_name="Test Project"
    )

    # Test deleting the project
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.delete(
        f"/api/v1/control/projects/{project_id}", headers=headers
    )

    assert resp.status_code == HTTPStatus.NO_CONTENT


@pytest.mark.asyncio
async def test_delete_project_without_access(
    api_key_client: tuple[AsyncClient, User, str],
    project_factory: ProjectFactory,
) -> None:
    """Test that user cannot delete project when they don't have access."""
    async_client, user, api_key = api_key_client

    # Create a project but don't associate user with it
    project = await project_factory.create_async()

    # Test deleting the project should fail
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.delete(
        f"/api/v1/control/projects/{project.id}", headers=headers
    )

    assert resp.status_code == HTTPStatus.FORBIDDEN
    data = resp.json()
    assert (
        f"User 'API Test User' does not have access to project {project.id}"
        in data["detail"]
    )


@pytest.mark.asyncio
async def test_list_projects_only_accessible(
    async_client: AsyncClient,
    project_factory: ProjectFactory,
    db_session: AsyncSession,
) -> None:
    """Test that list projects only returns accessible projects."""
    # Create a user with access to one project using helper
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Test User", project_name="Accessible Project"
    )

    # Create a second project that the user has no access to
    await project_factory.create_async(name="Inaccessible Project")

    # Test listing projects - should only see the accessible one
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get("/api/v1/control/projects", headers=headers)

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["name"] == "Accessible Project"
