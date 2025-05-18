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
    assert f'<tr id="agent-{agent.id}">' in resp.text
    assert agent.host_name in resp.text


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
