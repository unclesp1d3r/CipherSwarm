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
    _, project_id, api_key = await create_user_with_api_key_and_project_access(
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
    async_client, _user, api_key = api_key_client

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
    async_client, _user, api_key = api_key_client

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
    async_client, _user, api_key = api_key_client

    # Create a user with access to a project using helper
    _, project_id, api_key = await create_user_with_api_key_and_project_access(
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
    async_client, _user, api_key = api_key_client

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
    async_client, _user, api_key = api_key_client

    # Create a user with access to a project using helper
    _user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
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
    async_client, _user, api_key = api_key_client

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
    _, _project_id, api_key = await create_user_with_api_key_and_project_access(
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


@pytest.mark.asyncio
async def test_list_projects_offset_pagination(
    async_client: AsyncClient,
    project_factory: ProjectFactory,
    db_session: AsyncSession,
) -> None:
    """Test that offset-based pagination works correctly for Control API."""
    # Create a user with access to multiple projects using helper
    user_id, _, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Test User", project_name="Project Alpha"
    )

    # Create additional projects and associate the user with them
    from app.models.project import ProjectUserAssociation, ProjectUserRole

    project_beta = await project_factory.create_async(name="Project Beta")
    project_gamma = await project_factory.create_async(name="Project Gamma")
    project_delta = await project_factory.create_async(name="Project Delta")

    # Associate user with the additional projects
    for project in [project_beta, project_gamma, project_delta]:
        assoc = ProjectUserAssociation(
            project_id=project.id, user_id=user_id, role=ProjectUserRole.member
        )
        db_session.add(assoc)
    await db_session.commit()

    headers = {"Authorization": f"Bearer {api_key}"}

    # Test first page with limit=2, offset=0
    resp = await async_client.get(
        "/api/v1/control/projects?limit=2&offset=0", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] == 4  # Total projects user has access to
    assert data["limit"] == 2
    assert data["offset"] == 0
    assert len(data["items"]) == 2

    # Test second page with limit=2, offset=2
    resp = await async_client.get(
        "/api/v1/control/projects?limit=2&offset=2", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] == 4
    assert data["limit"] == 2
    assert data["offset"] == 2
    assert len(data["items"]) == 2

    # Test third page with limit=2, offset=4 (should be empty)
    resp = await async_client.get(
        "/api/v1/control/projects?limit=2&offset=4", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] == 4
    assert data["limit"] == 2
    assert data["offset"] == 4
    assert len(data["items"]) == 0

    # Test with limit=3, offset=1 (should get 3 items starting from second)
    resp = await async_client.get(
        "/api/v1/control/projects?limit=3&offset=1", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] == 4
    assert data["limit"] == 3
    assert data["offset"] == 1
    assert len(data["items"]) == 3


@pytest.mark.asyncio
async def test_list_project_users_with_access(
    async_client: AsyncClient,
    db_session: AsyncSession,
) -> None:
    """Test that user can list project users when they have access."""
    # Create a user with access to a project using helper
    user_id, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Test User", project_name="Test Project"
    )

    # Test listing project users
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get(
        f"/api/v1/control/projects/{project_id}/users", headers=headers
    )

    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["name"] == "Test User"
    assert data["items"][0]["id"] == str(user_id)


@pytest.mark.asyncio
async def test_list_project_users_without_access(
    api_key_client: tuple[AsyncClient, User, str],
    project_factory: ProjectFactory,
) -> None:
    """Test that user cannot list project users when they don't have access."""
    async_client, _user, api_key = api_key_client

    # Create a project but don't associate user with it
    project = await project_factory.create_async()

    # Test listing project users should fail
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get(
        f"/api/v1/control/projects/{project.id}/users", headers=headers
    )

    assert resp.status_code == HTTPStatus.FORBIDDEN
    data = resp.json()
    assert (
        f"User 'API Test User' does not have access to project {project.id}"
        in data["detail"]
    )


@pytest.mark.asyncio
async def test_list_project_users_nonexistent_project(
    api_key_client: tuple[AsyncClient, User, str],
) -> None:
    """Test that listing users for a nonexistent project returns 404."""
    async_client, _user, api_key = api_key_client

    # Test listing users for a nonexistent project
    headers = {"Authorization": f"Bearer {api_key}"}
    resp = await async_client.get(
        "/api/v1/control/projects/99999/users", headers=headers
    )

    assert resp.status_code == HTTPStatus.NOT_FOUND
    data = resp.json()
    assert "Project 99999 not found in database" in data["detail"]


@pytest.mark.asyncio
async def test_list_project_users_pagination(
    async_client: AsyncClient,
    db_session: AsyncSession,
    project_factory: ProjectFactory,
) -> None:
    """Test that pagination works correctly for project users listing."""
    from app.models.project import Project, ProjectUserAssociation, ProjectUserRole
    from tests.factories.user_factory import UserFactory

    # Create a project and a user with access using the helper
    _, project_id, api_key = await create_user_with_api_key_and_project_access(
        db_session, user_name="Main User", project_name="Test Project"
    )

    # Get the project object
    project = await db_session.get(Project, project_id)
    assert project is not None

    # Create additional users and associate them with the project
    for i in range(4):  # Create 4 more users (total 5 with the main user)
        user = await UserFactory.create_async(
            name=f"User {i + 2}", email=f"user{i + 2}@example.com"
        )

        # Associate user with project
        assoc = ProjectUserAssociation(
            project_id=project.id, user_id=user.id, role=ProjectUserRole.member
        )
        db_session.add(assoc)

    await db_session.commit()

    headers = {"Authorization": f"Bearer {api_key}"}

    # Test first page with limit=2, offset=0
    resp = await async_client.get(
        f"/api/v1/control/projects/{project.id}/users?limit=2&offset=0", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] == 5
    assert data["limit"] == 2
    assert data["offset"] == 0
    assert len(data["items"]) == 2

    # Test second page with limit=2, offset=2
    resp = await async_client.get(
        f"/api/v1/control/projects/{project.id}/users?limit=2&offset=2", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] == 5
    assert data["limit"] == 2
    assert data["offset"] == 2
    assert len(data["items"]) == 2

    # Test last page with limit=2, offset=4
    resp = await async_client.get(
        f"/api/v1/control/projects/{project.id}/users?limit=2&offset=4", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["total"] == 5
    assert data["limit"] == 2
    assert data["offset"] == 4
    assert len(data["items"]) == 1  # Only one user left
