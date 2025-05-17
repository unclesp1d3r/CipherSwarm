from http import HTTPStatus

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import create_access_token
from app.models.user import UserRole
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
    # View project info (HTML fragment)
    resp = await async_client.get(
        f"/api/v1/web/projects/{project_id}", headers={"HX-Request": "true"}
    )
    assert resp.status_code == HTTPStatus.OK
    assert "Viewable Project" in resp.text
    assert resp.headers["content-type"].startswith("text/html")


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
    resp = await async_client.get(
        f"/api/v1/web/projects/{project_id}", headers={"HX-Request": "true"}
    )
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
    resp = await async_client.get(
        f"/api/v1/web/projects/{project_id}", headers={"HX-Request": "true"}
    )
    assert resp.status_code in (HTTPStatus.UNAUTHORIZED, HTTPStatus.FORBIDDEN)


@pytest.mark.asyncio
async def test_view_nonexistent_project_returns_404(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin = await UserFactory.create_async(is_superuser=True, role=UserRole.ADMIN)
    async_client.cookies.set("access_token", create_access_token(admin.id))
    resp = await async_client.get(
        "/api/v1/web/projects/999999", headers={"HX-Request": "true"}
    )
    assert resp.status_code == HTTPStatus.NOT_FOUND
    assert "not found" in resp.text.lower()
