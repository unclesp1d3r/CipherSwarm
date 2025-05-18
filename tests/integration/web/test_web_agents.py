import datetime

import pytest
from httpx import AsyncClient, codes
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.models.agent import Agent, AgentState, OperatingSystemEnum
from app.models.agent_error import Severity
from app.models.hash_type import HashType
from app.models.hashcat_benchmark import HashcatBenchmark
from app.models.user import UserRole
from tests.factories.agent_error_factory import AgentErrorFactory
from tests.factories.agent_factory import AgentFactory
from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.task_factory import TaskFactory
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


async def test_agent_error_log_fragment(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    agent = await AgentFactory.create_async()
    project = await ProjectFactory.create_async()
    hash_list = await HashListFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await AttackFactory.create_async(
        campaign_id=campaign.id, hash_list_id=hash_list.id
    )
    task = await TaskFactory.create_async(attack_id=attack.id, agent_id=agent.id)
    now = datetime.datetime.now(datetime.UTC)
    await AgentErrorFactory.create_async(
        agent_id=agent.id,
        message="Minor error occurred",
        severity=Severity.minor,
        error_code="E100",
        task_id=None,
        details=None,
        created_at=now,
    )
    await AgentErrorFactory.create_async(
        agent_id=agent.id,
        message="Critical failure",
        severity=Severity.critical,
        error_code="E500",
        task_id=task.id,
        details=None,
        created_at=now,
    )
    # Call the endpoint
    resp = await async_client.get(f"/api/v1/web/agents/{agent.id}/errors")
    assert resp.status_code == codes.OK
    # Should contain both error messages
    assert "Minor error occurred" in resp.text
    assert "Critical failure" in resp.text
    # Should show color-coded severity
    assert "bg-yellow-100" in resp.text or "bg-red-100" in resp.text
    # Should show error codes and task id
    assert "E100" in resp.text
    assert "E500" in resp.text
    assert f"#{task.id}" in resp.text


async def test_toggle_agent_devices(
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
    # Create an agent with 3 devices
    agent = Agent(
        host_name="toggle-devices-agent",
        client_signature="sig-toggle-devices",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_5_testtoken",
        devices=["GPU0", "GPU1", "CPU"],
        enabled=True,
        advanced_configuration={},
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    cookies = {"access_token": token}
    # Enable devices 1 and 3 (1-indexed)
    resp = await async_client.patch(
        f"/api/v1/web/agents/{agent.id}/devices",
        data={"enabled_indices": ["1", "3"]},
        cookies=cookies,
        headers={"hx-request": "true"},
    )
    assert resp.status_code == codes.OK
    # Re-query agent to ensure latest state
    agent = (
        await db_session.execute(select(Agent).filter(Agent.id == agent.id))
    ).scalar_one()
    backend_device = (
        agent.advanced_configuration["backend_device"]
        if agent.advanced_configuration
        and "backend_device" in agent.advanced_configuration
        else None
    )
    assert backend_device == "1,3"
    # Modal fragment should show toggles checked for GPU0 and CPU
    assert "checked" in resp.text
    # Disable all devices
    resp2 = await async_client.patch(
        f"/api/v1/web/agents/{agent.id}/devices",
        data={},
        cookies=cookies,
        headers={"hx-request": "true"},
    )
    assert resp2.status_code == codes.OK
    agent = (
        await db_session.execute(select(Agent).filter(Agent.id == agent.id))
    ).scalar_one()
    backend_device2 = (
        agent.advanced_configuration["backend_device"]
        if agent.advanced_configuration
        and "backend_device" in agent.advanced_configuration
        else None
    )
    assert backend_device2 == ""
    # Non-admin cannot toggle
    user = user_factory.build()
    user.is_superuser = False
    user.role = UserRole.ANALYST
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    user_token = create_access_token(user.id)
    user_cookies = {"access_token": user_token}
    resp3 = await async_client.patch(
        f"/api/v1/web/agents/{agent.id}/devices",
        data={"enabled_indices": ["2"]},
        cookies=user_cookies,
        headers={"hx-request": "true"},
    )
    assert resp3.status_code == codes.FORBIDDEN
