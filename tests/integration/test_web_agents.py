import datetime

import pytest
from httpx import AsyncClient, codes
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.models.agent import Agent, AgentState, OperatingSystemEnum
from app.models.hash_type import HashType
from app.models.hashcat_benchmark import HashcatBenchmark
from app.models.user import UserRole
from tests.factories.user_factory import UserFactory

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


async def test_toggle_agent_enabled(
    async_client: AsyncClient, db_session: AsyncSession, user_factory: UserFactory
) -> None:
    # Create an admin user
    admin_user = user_factory.build()
    admin_user.is_superuser = True
    admin_user.role = UserRole.ADMIN
    db_session.add(admin_user)
    await db_session.commit()
    await db_session.refresh(admin_user)
    token = create_access_token(admin_user.id)
    # Create an agent
    agent = Agent(
        host_name="toggle-agent-1",
        client_signature="sig-toggle-123",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_3_testtoken",
        devices=["NVIDIA GTX 1070"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    cookies = {"access_token": token}
    resp = await async_client.patch(f"/api/v1/web/agents/{agent.id}", cookies=cookies)
    assert resp.status_code == codes.OK
    await db_session.refresh(agent)
    assert agent.enabled is False
    assert f"agent-{agent.id}" in resp.text
    # Toggle back
    resp2 = await async_client.patch(f"/api/v1/web/agents/{agent.id}", cookies=cookies)
    assert resp2.status_code == codes.OK
    await db_session.refresh(agent)
    assert agent.enabled is True


@pytest.mark.asyncio
async def test_agent_benchmark_summary_fragment(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Use pre-seeded hash types from reset_db_and_seed_hash_types
    md5 = await db_session.execute(select(HashType).where(HashType.id == 0))
    sha1 = await db_session.execute(select(HashType).where(HashType.id == 1))
    ht1 = md5.scalar_one()
    ht2 = sha1.scalar_one()
    # Create agent
    agent = Agent(
        host_name="bench-agent-1",
        client_signature="sig-bench-123",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_4_testtoken",
        devices=["NVIDIA GTX 1080", "NVIDIA RTX 3090"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    # Add benchmarks
    now = datetime.datetime.now(datetime.UTC)
    b1 = HashcatBenchmark(
        agent_id=agent.id,
        hash_type_id=ht1.id,
        runtime=100,
        hash_speed=1000000.0,
        device="NVIDIA GTX 1080",
        created_at=now,
    )
    b2 = HashcatBenchmark(
        agent_id=agent.id,
        hash_type_id=ht1.id,
        runtime=120,
        hash_speed=2000000.0,
        device="NVIDIA RTX 3090",
        created_at=now,
    )
    b3 = HashcatBenchmark(
        agent_id=agent.id,
        hash_type_id=ht2.id,
        runtime=150,
        hash_speed=500000.0,
        device="NVIDIA GTX 1080",
        created_at=now,
    )
    db_session.add_all([b1, b2, b3])
    await db_session.commit()
    # Call the endpoint
    resp = await async_client.get(f"/api/v1/web/agents/{agent.id}/benchmarks")
    assert resp.status_code == codes.OK
    # Should contain hash mode names and device names
    assert ht1.name in resp.text
    assert ht2.name in resp.text
    assert "NVIDIA GTX 1080" in resp.text
    assert "NVIDIA RTX 3090" in resp.text
    # Should show SI-formatted speeds
    assert (
        "1.00 Kh/s" in resp.text or "2.00 Kh/s" in resp.text or "3.00 Kh/s" in resp.text
    )
    # Should show the Benchmark Summary header
    assert "Benchmark Summary" in resp.text
