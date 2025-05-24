from http import HTTPStatus

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import hash_password
from app.core.security import create_access_token
from app.models.attack import AttackMode
from app.models.user import User, UserRole
from app.schemas.shared import AttackTemplate, AttackTemplateRecordCreate


def _setup_admin_user(db_session: AsyncSession) -> User:
    admin_user = User(
        email="admin@example.com",
        name="Admin User",
        hashed_password=hash_password("adminpass"),
        is_active=True,
        is_superuser=True,
        role=UserRole.ADMIN,
    )
    db_session.add(admin_user)
    return admin_user


def _setup_regular_user(db_session: AsyncSession) -> User:
    user_user = User(
        email="user@example.com",
        name="Normal User",
        hashed_password=hash_password("userpass"),
        is_active=True,
        is_superuser=False,
        role=UserRole.ANALYST,
    )
    db_session.add(user_user)
    return user_user


def _setup_users(db_session: AsyncSession) -> tuple[User, User]:
    admin_user = _setup_admin_user(db_session)
    user_user = _setup_regular_user(db_session)
    return admin_user, user_user


def _template_data() -> AttackTemplateRecordCreate:
    return AttackTemplateRecordCreate(
        name="Test Template",
        description="A recommended mask template",
        attack_mode="mask",
        recommended=True,
        project_ids=None,
        template_json=AttackTemplate(
            mode=AttackMode.MASK,
            min_length=8,
            max_length=12,
            masks=["?l?l?l?l?l?l?l?l"],
        ),
    )


@pytest.mark.asyncio
async def test_template_crud_admin_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin_user: User = _setup_admin_user(db_session)
    await db_session.commit()
    await db_session.refresh(admin_user)
    admin_token = create_access_token(str(admin_user.id))
    auth_headers_admin = {"Authorization": f"Bearer {admin_token}"}
    template_data = _template_data()
    # Create
    resp = await async_client.post(
        "/api/v1/web/templates/",
        json=template_data.model_dump(),
        headers=auth_headers_admin,
    )
    assert resp.status_code == HTTPStatus.CREATED
    template = resp.json()
    template_id = template["id"]

    # List as admin
    resp = await async_client.get(
        "/api/v1/web/templates/",
        headers=auth_headers_admin,
    )
    assert resp.status_code == HTTPStatus.OK
    assert any(t["id"] == template_id for t in resp.json())

    # Get as admin
    resp = await async_client.get(
        f"/api/v1/web/templates/{template_id}", headers=auth_headers_admin
    )
    assert resp.status_code == HTTPStatus.OK

    # Update as admin
    resp = await async_client.patch(
        f"/api/v1/web/templates/{template_id}",
        json={"description": "Updated desc"},
        headers=auth_headers_admin,
    )
    assert resp.status_code == HTTPStatus.OK
    assert resp.json()["description"] == "Updated desc"

    # Delete as admin
    resp = await async_client.delete(
        f"/api/v1/web/templates/{template_id}", headers=auth_headers_admin
    )
    assert resp.status_code == HTTPStatus.NO_CONTENT


@pytest.mark.asyncio
async def test_template_create_forbidden_for_non_admin(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    user_user = _setup_regular_user(db_session)

    await db_session.commit()
    await db_session.refresh(user_user)
    user_token = create_access_token(str(user_user.id))
    auth_headers_user = {"Authorization": f"Bearer {user_token}"}
    template_data = _template_data()
    resp = await async_client.post(
        "/api/v1/web/templates/",
        json=template_data.model_dump(),
        headers=auth_headers_user,
    )
    assert resp.status_code == HTTPStatus.FORBIDDEN


@pytest.mark.asyncio
async def test_template_update_forbidden_for_non_admin(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin_user, user_user = _setup_users(db_session)
    await db_session.commit()
    await db_session.refresh(admin_user)
    await db_session.refresh(user_user)
    admin_token = create_access_token(str(admin_user.id))
    user_token = create_access_token(str(user_user.id))
    auth_headers_admin = {"Authorization": f"Bearer {admin_token}"}
    auth_headers_user = {"Authorization": f"Bearer {user_token}"}
    template_data = _template_data()

    # Create as admin
    resp = await async_client.post(
        "/api/v1/web/templates/",
        json=template_data.model_dump(),
        headers=auth_headers_admin,
    )
    assert resp.status_code == HTTPStatus.CREATED
    template_id = resp.json()["id"]

    # Try update as non-admin
    resp = await async_client.patch(
        f"/api/v1/web/templates/{template_id}",
        json={"description": "Should not work"},
        headers=auth_headers_user,
    )
    assert resp.status_code == HTTPStatus.FORBIDDEN


@pytest.mark.asyncio
async def test_template_delete_forbidden_for_non_admin(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    admin_user, user_user = _setup_users(db_session)
    await db_session.commit()
    await db_session.refresh(admin_user)
    await db_session.refresh(user_user)
    admin_token = create_access_token(str(admin_user.id))
    user_token = create_access_token(str(user_user.id))
    auth_headers_admin = {"Authorization": f"Bearer {admin_token}"}
    auth_headers_user = {"Authorization": f"Bearer {user_token}"}
    template_data = _template_data()

    # Create as admin
    resp = await async_client.post(
        "/api/v1/web/templates/",
        json=template_data.model_dump(),
        headers=auth_headers_admin,
    )
    assert resp.status_code == HTTPStatus.CREATED
    template_id = resp.json()["id"]

    # Try delete as non-admin
    resp = await async_client.delete(
        f"/api/v1/web/templates/{template_id}", headers=auth_headers_user
    )
    assert resp.status_code == HTTPStatus.FORBIDDEN
