from http import HTTPStatus

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import create_access_token
from app.models.user import UserRole
from tests.factories.project_factory import ProjectFactory
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_admin_can_create_project(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    async_client.cookies.set("access_token", create_access_token(admin.id))
    payload = {
        "name": "Test Project",
        "description": "A project created by admin",
        "private": False,
        "notes": "Initial notes",
    }
    resp = await async_client.post("/api/v1/web/projects", json=payload)
    assert resp.status_code == HTTPStatus.CREATED
    data = resp.json()
    assert data["name"] == payload["name"]
    assert data["description"] == payload["description"]
    assert data["private"] is False
    assert data["notes"] == payload["notes"]


@pytest.mark.asyncio
async def test_non_admin_cannot_create_project(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = await UserFactory.create_async(is_superuser=False, role=UserRole.ANALYST)
    async_client.cookies.set("access_token", create_access_token(user.id))
    payload = {"name": "Should Fail", "description": "No admin rights", "private": True}
    resp = await async_client.post("/api/v1/web/projects", json=payload)
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert "Not authorized" in resp.text


@pytest.mark.asyncio
async def test_unauthenticated_cannot_create_project(async_client: AsyncClient) -> None:
    payload = {"name": "No Auth", "description": "Should fail", "private": False}
    resp = await async_client.post("/api/v1/web/projects", json=payload)
    assert resp.status_code in (HTTPStatus.UNAUTHORIZED, HTTPStatus.FORBIDDEN)


@pytest.mark.asyncio
async def test_create_project_validation_error(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    async_client.cookies.set("access_token", create_access_token(admin.id))
    payload = {"description": "Missing name field", "private": False}
    resp = await async_client.post("/api/v1/web/projects", json=payload)
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
    assert "name" in resp.text or "field required" in resp.text


@pytest.mark.asyncio
async def test_admin_can_view_project_info(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    async_client.cookies.set("access_token", create_access_token(admin.id))
    # Create a project
    payload = {
        "name": "Viewable Project",
        "description": "Project for info view",
        "private": False,
        "notes": "Info notes",
    }
    resp = await async_client.post("/api/v1/web/projects", json=payload)
    assert resp.status_code == HTTPStatus.CREATED
    project_id = resp.json()["id"]
    # View project info (JSON)
    resp = await async_client.get(f"/api/v1/web/projects/{project_id}")
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["name"] == "Viewable Project"
    assert data["description"] == "Project for info view"
    assert data["private"] is False
    assert data["notes"] == "Info notes"


@pytest.mark.asyncio
async def test_non_admin_cannot_view_project_info(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = await UserFactory.create_async(is_superuser=False, role=UserRole.ANALYST)
    async_client.cookies.set("access_token", create_access_token(user.id))
    # Create a project as admin
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    admin_client = async_client
    admin_client.cookies.set("access_token", create_access_token(admin.id))
    payload = {
        "name": "Hidden Project",
        "description": "Should not be visible",
        "private": True,
    }
    resp = await admin_client.post("/api/v1/web/projects", json=payload)
    assert resp.status_code == HTTPStatus.CREATED
    project_id = resp.json()["id"]
    # Try to view as non-admin
    async_client.cookies.set("access_token", create_access_token(user.id))
    resp = await async_client.get(f"/api/v1/web/projects/{project_id}")
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert "Not authorized" in resp.text


@pytest.mark.asyncio
async def test_unauthenticated_cannot_view_project_info(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create a project as admin
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    admin_client = async_client
    admin_client.cookies.set("access_token", create_access_token(admin.id))
    payload = {
        "name": "NoAuth Project",
        "description": "Should not be visible",
        "private": False,
    }
    resp = await admin_client.post("/api/v1/web/projects", json=payload)
    assert resp.status_code == HTTPStatus.CREATED
    project_id = resp.json()["id"]
    # Try to view as unauthenticated
    async_client.cookies.clear()
    resp = await async_client.get(f"/api/v1/web/projects/{project_id}")
    assert resp.status_code in (HTTPStatus.UNAUTHORIZED, HTTPStatus.FORBIDDEN)


@pytest.mark.asyncio
async def test_view_nonexistent_project_returns_404(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    async_client.cookies.set("access_token", create_access_token(admin.id))
    resp = await async_client.get("/api/v1/web/projects/999999")
    assert resp.status_code == HTTPStatus.NOT_FOUND
    assert "not found" in resp.text.lower()


@pytest.mark.asyncio
async def test_admin_can_patch_project(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    user1 = await UserFactory.create_async()
    user2 = await UserFactory.create_async()
    async_client.cookies.set("access_token", create_access_token(admin.id))
    # Create project
    payload = {
        "name": "Patchable Project",
        "description": "desc",
        "private": False,
        "notes": "n",
    }
    resp = await async_client.post("/api/v1/web/projects", json=payload)
    assert resp.status_code == HTTPStatus.CREATED
    project_id = resp.json()["id"]
    # Patch name, private, notes, users
    patch_payload = {
        "name": "Patched Name",
        "private": True,
        "notes": "Updated notes",
        "users": [str(user1.id), str(user2.id)],
    }
    resp = await async_client.patch(
        f"/api/v1/web/projects/{project_id}",
        json=patch_payload,
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["name"] == "Patched Name"
    assert data["notes"] == "Updated notes"
    assert data["private"] is True
    # Confirm users in response
    assert str(user1.id) in [str(uid) for uid in data["users"]]
    assert str(user2.id) in [str(uid) for uid in data["users"]]


@pytest.mark.asyncio
async def test_non_admin_cannot_patch_project(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = await UserFactory.create_async(is_superuser=False, role=UserRole.ANALYST)
    async_client.cookies.set("access_token", create_access_token(user.id))
    project = await ProjectFactory.create_async()
    patch_payload = {"name": "Should Not Work"}
    resp = await async_client.patch(
        f"/api/v1/web/projects/{project.id}",
        json=patch_payload,
    )
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert "Not authorized" in resp.text


@pytest.mark.asyncio
async def test_patch_project_not_found(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    async_client.cookies.set("access_token", create_access_token(admin.id))
    patch_payload = {"name": "Does Not Exist"}
    resp = await async_client.patch(
        "/api/v1/web/projects/999999",
        json=patch_payload,
    )
    assert resp.status_code == HTTPStatus.NOT_FOUND
    assert "not found" in resp.text.lower()


@pytest.mark.asyncio
async def test_patch_project_validation_error(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    async_client.cookies.set("access_token", create_access_token(admin.id))
    project = await ProjectFactory.create_async()
    patch_payload = {"private": "notabool"}
    resp = await async_client.patch(
        f"/api/v1/web/projects/{project.id}",
        json=patch_payload,
    )
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
    assert (
        "value could not be parsed" in resp.text
        or "type error" in resp.text.lower()
        or "Input should be a valid boolean" in resp.text
    )


@pytest.mark.asyncio
async def test_patch_project_updates_users(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    user1 = await UserFactory.create_async()
    user2 = await UserFactory.create_async()
    user3 = await UserFactory.create_async()
    async_client.cookies.set("access_token", create_access_token(admin.id))
    # Create project with user1 and user2
    payload = {"name": "User Assign Project", "users": [str(user1.id), str(user2.id)]}
    resp = await async_client.post("/api/v1/web/projects", json=payload)
    assert resp.status_code == HTTPStatus.CREATED
    project_id = resp.json()["id"]
    # Patch to only user3
    patch_payload = {"users": [str(user3.id)]}
    resp = await async_client.patch(
        f"/api/v1/web/projects/{project_id}",
        json=patch_payload,
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert str(user3.id) in [str(uid) for uid in data["users"]]
    assert str(user1.id) not in [str(uid) for uid in data["users"]]
    assert str(user2.id) not in [str(uid) for uid in data["users"]]


@pytest.mark.asyncio
async def test_admin_can_archive_project(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    async_client.cookies.set("access_token", create_access_token(admin.id))
    project = await ProjectFactory.create_async()
    resp = await async_client.delete(f"/api/v1/web/projects/{project.id}")
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # Confirm archived_at is set
    from app.models.project import Project

    db_project = await db_session.get(Project, project.id)
    assert db_project is not None
    assert db_project.archived_at is not None


@pytest.mark.asyncio
async def test_non_admin_cannot_archive_project(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user = await UserFactory.create_async(is_superuser=False, role=UserRole.ANALYST)
    async_client.cookies.set("access_token", create_access_token(user.id))
    project = await ProjectFactory.create_async()
    resp = await async_client.delete(f"/api/v1/web/projects/{project.id}")
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert "Not authorized" in resp.text


@pytest.mark.asyncio
async def test_archive_project_not_found(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    async_client.cookies.set("access_token", create_access_token(admin.id))
    resp = await async_client.delete("/api/v1/web/projects/999999")
    assert resp.status_code == HTTPStatus.NOT_FOUND
    assert "not found" in resp.text.lower()


@pytest.mark.asyncio
async def test_archive_project_is_soft(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    async_client.cookies.set("access_token", create_access_token(admin.id))
    project = await ProjectFactory.create_async()
    # Archive project
    resp = await async_client.delete(f"/api/v1/web/projects/{project.id}")
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # Project should still exist in DB, but archived_at is set
    from app.models.project import Project

    db_project = await db_session.get(Project, project.id)
    assert db_project is not None
    assert db_project.archived_at is not None


@pytest.mark.asyncio
async def test_archived_project_not_listed_or_accessible(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    async_client.cookies.set("access_token", create_access_token(admin.id))
    # Create a project
    payload = {"name": "ArchiveMe", "description": "To be archived", "private": False}
    resp = await async_client.post("/api/v1/web/projects", json=payload)
    assert resp.status_code == HTTPStatus.CREATED
    project_id = resp.json()["id"]
    # Archive the project
    resp = await async_client.delete(f"/api/v1/web/projects/{project_id}")
    assert resp.status_code == HTTPStatus.NO_CONTENT
    # List projects - should not include archived
    resp = await async_client.get("/api/v1/web/projects")
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert all(p["name"] != "ArchiveMe" for p in data["items"])
    # Try to get project detail - should 404
    resp = await async_client.get(f"/api/v1/web/projects/{project_id}")
    assert resp.status_code == HTTPStatus.NOT_FOUND
    # Check user project context does not include archived project
    # Call the /auth/context endpoint to get the ContextResponse object
    context_resp = await async_client.get("/api/v1/web/auth/context")
    assert context_resp.status_code == HTTPStatus.OK
    context = (
        context_resp.json()
    )  # This will be a dict representation of ContextResponse

    available_projects = context["available_projects"]
    assert not any(p["name"] == "ArchiveMe" for p in available_projects), (
        "Archived project should not be in available_projects via context endpoint"
    )

    def get_id(obj: dict[str, object]) -> int:
        val = obj.get("id")
        if isinstance(val, int):
            return val
        if isinstance(val, str) and val.isdigit():
            return int(val)
        raise ValueError(f"Unexpected id type: {type(val)}")

    assert all(get_id(p) != int(project_id) for p in available_projects)
