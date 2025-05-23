from unittest.mock import patch

import httpx
import pytest
from httpx import AsyncClient, codes
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.models.agent import Agent, AgentState, OperatingSystemEnum
from app.models.user import UserRole
from tests.factories.user_factory import UserFactory

pytestmark = pytest.mark.asyncio


async def test_trigger_agent_benchmark(
    async_client: AsyncClient, db_session: AsyncSession, user_factory: UserFactory
) -> None:
    # Create an admin user (has all permissions)
    admin_user = user_factory.build()
    admin_user.is_superuser = True
    admin_user.role = UserRole.ADMIN
    db_session.add(admin_user)
    await db_session.commit()
    await db_session.refresh(admin_user)
    token = create_access_token(admin_user.id)
    # Create an agent
    agent = Agent(
        host_name="trigger-agent-1",
        client_signature="sig-trigger-123",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_5_testtoken",
        devices=["NVIDIA GTX 1080"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    cookies = {"access_token": token}
    resp = await async_client.post(
        f"/api/v1/web/agents/{agent.id}/benchmark", cookies=cookies
    )
    assert resp.status_code == codes.OK
    await db_session.refresh(agent)
    assert agent.state == AgentState.pending
    data = resp.json()
    assert data["id"] == agent.id
    assert data["host_name"] == agent.host_name


async def test_trigger_agent_benchmark_permission_denied(
    async_client: AsyncClient, db_session: AsyncSession, user_factory: UserFactory
) -> None:
    # Create a non-admin user (no permissions)
    user = user_factory.build()
    user.is_superuser = False
    user.role = UserRole.ANALYST
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    token = create_access_token(user.id)
    # Create an agent
    agent = Agent(
        host_name="trigger-agent-2",
        client_signature="sig-trigger-456",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_6_testtoken",
        devices=["NVIDIA GTX 1080"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    cookies = {"access_token": token}
    resp = await async_client.post(
        f"/api/v1/web/agents/{agent.id}/benchmark", cookies=cookies
    )
    assert resp.status_code == codes.FORBIDDEN
    assert resp.json()["error"] == "Not authorized to trigger benchmark for this agent"


@pytest.mark.asyncio
async def test_agent_presigned_url_valid(
    async_client: AsyncClient, db_session: AsyncSession, user_factory: UserFactory
) -> None:
    admin_user = user_factory.build()
    admin_user.is_superuser = True
    admin_user.role = UserRole.ADMIN
    db_session.add(admin_user)
    await db_session.commit()
    await db_session.refresh(admin_user)
    token = create_access_token(admin_user.id)
    agent = Agent(
        host_name="presigned-agent-1",
        client_signature="sig-presigned-123",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_7_testtoken",
        devices=["NVIDIA GTX 1080"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    cookies = {"access_token": token}
    url = "https://minio.example.com/wordlists/xyz123?X-Amz-Signature=abc"

    async def mock_head(
        self: httpx.AsyncClient, url: str, *args: object, **kwargs: object
    ) -> object:
        class MockResponse:
            status_code = codes.OK

        return MockResponse()

    with patch.object(httpx.AsyncClient, "head", mock_head):
        resp = await async_client.post(
            f"/api/v1/web/agents/{agent.id}/test_presigned",
            json={"payload": {"url": url}},
            cookies=cookies,
        )
    assert resp.status_code == codes.OK
    assert resp.json() == {"valid": True}


@pytest.mark.asyncio
async def test_agent_presigned_url_invalid(
    async_client: AsyncClient, db_session: AsyncSession, user_factory: UserFactory
) -> None:
    admin_user = user_factory.build()
    admin_user.is_superuser = True
    admin_user.role = UserRole.ADMIN
    db_session.add(admin_user)
    await db_session.commit()
    await db_session.refresh(admin_user)
    token = create_access_token(admin_user.id)
    agent = Agent(
        host_name="presigned-agent-2",
        client_signature="sig-presigned-456",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_8_testtoken",
        devices=["NVIDIA GTX 1080"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    cookies = {"access_token": token}
    url = "https://minio.example.com/wordlists/xyz123?X-Amz-Signature=abc"

    async def mock_head(
        self: httpx.AsyncClient, url: str, *args: object, **kwargs: object
    ) -> object:
        class MockResponse:
            status_code = codes.FORBIDDEN

        return MockResponse()

    with patch.object(httpx.AsyncClient, "head", mock_head):
        resp = await async_client.post(
            f"/api/v1/web/agents/{agent.id}/test_presigned",
            json={"payload": {"url": url}},
            cookies=cookies,
        )
    assert resp.status_code == codes.OK
    assert resp.json() == {"valid": False}


@pytest.mark.asyncio
async def test_agent_presigned_url_forbidden(
    async_client: AsyncClient, db_session: AsyncSession, user_factory: UserFactory
) -> None:
    user = user_factory.build()
    user.is_superuser = False
    user.role = UserRole.ANALYST
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    token = create_access_token(user.id)
    agent = Agent(
        host_name="presigned-agent-3",
        client_signature="sig-presigned-789",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_9_testtoken",
        devices=["NVIDIA GTX 1080"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    cookies = {"access_token": token}
    url = "https://minio.example.com/wordlists/xyz123?X-Amz-Signature=abc"
    resp = await async_client.post(
        f"/api/v1/web/agents/{agent.id}/test_presigned",
        json={"payload": {"url": url}},
        cookies=cookies,
    )
    assert resp.status_code == codes.FORBIDDEN
    assert resp.json()["error"] == "Admin only"


@pytest.mark.asyncio
async def test_agent_presigned_url_invalid_input(
    async_client: AsyncClient, db_session: AsyncSession, user_factory: UserFactory
) -> None:
    admin_user = user_factory.build()
    admin_user.is_superuser = True
    admin_user.role = UserRole.ADMIN
    db_session.add(admin_user)
    await db_session.commit()
    await db_session.refresh(admin_user)
    token = create_access_token(admin_user.id)
    agent = Agent(
        host_name="presigned-agent-4",
        client_signature="sig-presigned-000",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_10_testtoken",
        devices=["NVIDIA GTX 1080"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    cookies = {"access_token": token}
    # Invalid URL (not http/https)
    resp = await async_client.post(
        f"/api/v1/web/agents/{agent.id}/test_presigned",
        json={"payload": {"url": "file:///etc/passwd"}},
        cookies=cookies,
    )
    assert resp.status_code == codes.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_agent_presigned_url_agent_not_found(
    async_client: AsyncClient, db_session: AsyncSession, user_factory: UserFactory
) -> None:
    admin_user = user_factory.build()
    admin_user.is_superuser = True
    admin_user.role = UserRole.ADMIN
    db_session.add(admin_user)
    await db_session.commit()
    await db_session.refresh(admin_user)
    token = create_access_token(admin_user.id)
    cookies = {"access_token": token}
    url = "https://minio.example.com/wordlists/xyz123?X-Amz-Signature=abc"
    resp = await async_client.post(
        "/api/v1/web/agents/999999/test_presigned",
        json={"payload": {"url": url}},
        cookies=cookies,
    )
    assert resp.status_code == codes.NOT_FOUND
    assert resp.json()["error"] == "Agent not found"
