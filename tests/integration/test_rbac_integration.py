from collections.abc import Callable, Coroutine
from typing import Any

import httpx
import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.models.campaign import Campaign
from app.models.project import Project
from app.models.user import User
from tests.factories.hash_item_factory import HashItemFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.user_factory import UserFactory

pytestmark = pytest.mark.asyncio


@pytest.fixture
def user_factory() -> UserFactory:
    return UserFactory()


@pytest.fixture
def project_factory(
    db_session: AsyncSession,
) -> Callable[..., Coroutine[Any, Any, Project]]:
    async def _create_project(**kwargs: Any) -> Project:
        project = Project(**kwargs)
        db_session.add(project)
        await db_session.commit()
        await db_session.refresh(project)
        return project

    return _create_project


@pytest.fixture
def campaign_factory(
    db_session: AsyncSession,
) -> Callable[..., Coroutine[Any, Any, Campaign]]:
    async def _create_campaign(**kwargs: Any) -> Campaign:
        # Ensure required fields are set
        if "project_id" not in kwargs or kwargs["project_id"] is None:
            raise ValueError("project_id is required for campaign_factory")
        # Remove created_by_id if present, since Campaign does not accept it
        kwargs.pop("created_by_id", None)
        # Build HashList and HashItem, add to session, commit
        hash_list = HashListFactory.build(project_id=kwargs["project_id"])
        hash_item = HashItemFactory.build()
        hash_list.items.append(hash_item)
        db_session.add(hash_list)
        await db_session.flush()
        await db_session.commit()
        kwargs["hash_list_id"] = hash_list.id
        campaign = Campaign(**kwargs)
        db_session.add(campaign)
        await db_session.commit()
        await db_session.refresh(campaign)
        return campaign

    return _create_campaign


@pytest.fixture
def auth_header() -> Callable[[User], dict[str, str]]:
    def _header(user: User) -> dict[str, str]:
        token = create_access_token(user.id)
        return {"Authorization": f"Bearer {token}"}

    return _header


async def test_system_admin_can_access_user_management(
    db_session: AsyncSession,
    user_factory: UserFactory,
    auth_header: Callable[..., dict[str, str]],
    async_client: AsyncClient,
) -> None:
    admin = user_factory.build(
        name="SysAdmin", email="sysadmin@example.com", is_superuser=True
    )
    db_session.add(admin)
    await db_session.commit()
    await db_session.refresh(admin)
    headers = auth_header(admin)
    resp = await async_client.get("/api/v1/web/users", headers=headers)
    assert resp.status_code == httpx.codes.OK
    assert "users" in resp.text or resp.json()
