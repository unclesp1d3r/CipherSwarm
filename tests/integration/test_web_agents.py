import pytest
from httpx import AsyncClient, codes
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent import Agent, AgentState, OperatingSystemEnum

pytestmark = pytest.mark.asyncio


async def test_list_agents_fragment(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    agent = Agent(
        host_name="test-agent-1",
        client_signature="sig-123",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_1_testtoken",
        devices=["NVIDIA GTX 1080"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    resp = await async_client.get("/api/v1/web/agents")
    assert resp.status_code == codes.OK
    assert "test-agent-1" in resp.text
    assert "Agents" not in resp.text  # Only the table fragment is returned
    assert "NVIDIA GTX 1080" in resp.text


async def test_list_agents_fragment_filter_state(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    agent = Agent(
        host_name="test-agent-1",
        client_signature="sig-123",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_1_testtoken",
        devices=["NVIDIA GTX 1080"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    resp = await async_client.get("/api/v1/web/agents?state=active")
    assert resp.status_code == codes.OK
    assert "test-agent-1" in resp.text
    resp2 = await async_client.get("/api/v1/web/agents?state=stopped")
    assert resp2.status_code == codes.OK
    assert "test-agent-1" not in resp2.text


async def test_agent_detail_modal(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    agent = Agent(
        host_name="detail-agent-1",
        client_signature="sig-detail-123",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_2_testtoken",
        devices=["NVIDIA RTX 3090"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    resp = await async_client.get(f"/api/v1/web/agents/{agent.id}")
    assert resp.status_code == codes.OK
    assert "Agent Details" in resp.text
    assert "detail-agent-1" in resp.text
    assert "NVIDIA RTX 3090" in resp.text
    assert "Operating System" in resp.text
    assert "Client Signature" in resp.text
    assert "State" in resp.text
