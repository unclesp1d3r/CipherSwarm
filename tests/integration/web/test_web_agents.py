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


async def test_list_agents_json(
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
    data = resp.json()
    assert "items" in data
    assert any(a["host_name"] == "test-agent-1" for a in data["items"])
    assert any("NVIDIA GTX 1080" in a["devices"] for a in data["items"])
    assert data["page"] == 1
    assert data["page_size"] >= 1
    assert data["total"] >= 1


async def test_list_agents_json_filter_state(
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
    data = resp.json()
    assert any(a["host_name"] == "test-agent-1" for a in data["items"])
    resp2 = await async_client.get("/api/v1/web/agents?state=stopped")
    assert resp2.status_code == codes.OK
    data2 = resp2.json()
    assert all(a["host_name"] != "test-agent-1" for a in data2["items"])


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
    data = resp.json()
    assert data["host_name"] == "detail-agent-1"
    assert data["client_signature"] == "sig-detail-123"
    assert "NVIDIA RTX 3090" in data["devices"]
    assert data["operating_system"] == "linux"
    assert data["state"] == "active"


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
    data = resp.json()
    # Check that hash type IDs are present as keys
    assert str(ht1.id) in data["benchmarks_by_hash_type"]
    assert str(ht2.id) in data["benchmarks_by_hash_type"]
    # Check device names and speeds in the returned data
    found_devices = set()
    for bench_list in data["benchmarks_by_hash_type"].values():
        for bench in bench_list:
            found_devices.add(bench["device"])
            assert "hash_speed" in bench
    assert "NVIDIA GTX 1080" in found_devices
    assert "NVIDIA RTX 3090" in found_devices


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
    data = resp.json()
    messages = [e["message"] for e in data["errors"]]
    assert "Minor error occurred" in messages
    assert "Critical failure" in messages
    codes_ = [e["error_code"] for e in data["errors"]]
    assert "E100" in codes_
    assert "E500" in codes_
    task_ids = [e["task_id"] for e in data["errors"]]
    assert task.id in task_ids


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
        json={"enabled_indices": ["1", "3"]},
        cookies=cookies,
        headers={"hx-request": "true"},
    )
    assert resp.status_code == codes.OK
    data = resp.json()
    agent_out = data["agent"]
    assert agent_out["host_name"] == "toggle-devices-agent"
    assert agent_out["advanced_configuration"]["backend_device"] == "1,3"
    # Disable all devices
    resp2 = await async_client.patch(
        f"/api/v1/web/agents/{agent.id}/devices",
        json={"enabled_indices": []},
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
        json={"enabled_indices": ["2"]},
        cookies=user_cookies,
        headers={"hx-request": "true"},
    )
    assert resp3.status_code == codes.FORBIDDEN


async def test_agent_performance_fragment(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    agent = Agent(
        host_name="perf-agent-1",
        client_signature="sig-perf-123",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_6_testtoken",
        devices=["NVIDIA GTX 1080", "NVIDIA RTX 3090"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    # Insert some performance data for both devices
    import datetime

    from app.models.agent_device_performance import AgentDevicePerformance

    now = datetime.datetime.now(datetime.UTC)
    db_session.add_all(
        [
            AgentDevicePerformance(
                agent_id=agent.id,
                device_name="NVIDIA GTX 1080",
                timestamp=now,
                speed=12345.0,
            ),
            AgentDevicePerformance(
                agent_id=agent.id,
                device_name="NVIDIA RTX 3090",
                timestamp=now,
                speed=54321.0,
            ),
        ]
    )
    await db_session.commit()
    resp = await async_client.get(f"/api/v1/web/agents/{agent.id}/performance")
    assert resp.status_code == codes.OK
    data = resp.json()
    devices = [series["device"] for series in data["series"]]
    assert "NVIDIA GTX 1080" in devices
    assert "NVIDIA RTX 3090" in devices
    for series in data["series"]:
        assert "data" in series
        for point in series["data"]:
            assert "timestamp" in point
            assert "speed" in point


@pytest.mark.asyncio
async def test_register_agent_success(
    async_client: AsyncClient, db_session: AsyncSession, user_factory: UserFactory
) -> None:
    agent_update_interval = 45
    admin_user = user_factory.build()
    admin_user.is_superuser = True
    admin_user.role = UserRole.ADMIN
    db_session.add(admin_user)
    await db_session.commit()
    await db_session.refresh(admin_user)
    token = create_access_token(admin_user.id)
    cookies = {"access_token": token}
    form_data = {
        "host_name": "webreg-agent-1",
        "operating_system": "linux",
        "client_signature": "sig-webreg-123",
        "custom_label": "Test Agent",
        "devices": "GPU0,GPU1",
        "agent_update_interval": agent_update_interval,
        "use_native_hashcat": True,
        "backend_device": "0",
        "opencl_devices": "0,1",
        "enable_additional_hash_types": True,
    }
    resp = await async_client.post(
        "/api/v1/web/agents", json=form_data, cookies=cookies
    )
    assert resp.status_code == codes.OK
    data = resp.json()
    assert data["agent"]["host_name"] == "webreg-agent-1"
    assert data["agent"]["client_signature"] == "sig-webreg-123"
    assert data["agent"]["custom_label"] == "Test Agent"
    assert "GPU0" in data["agent"]["devices"]
    assert "GPU1" in data["agent"]["devices"]
    assert data["token"].startswith("csa_")
    # Agent should exist in DB
    agent = (
        await db_session.execute(
            select(Agent).where(Agent.client_signature == "sig-webreg-123")
        )
    ).scalar_one_or_none()
    assert agent is not None
    assert agent.host_name == "webreg-agent-1"
    assert agent.custom_label == "Test Agent"
    assert agent.enabled is True
    assert agent.devices == ["GPU0", "GPU1"]
    assert agent.advanced_configuration is not None
    assert (
        agent.advanced_configuration["agent_update_interval"] == agent_update_interval
    )
    assert agent.advanced_configuration["use_native_hashcat"] is True
    assert agent.advanced_configuration["backend_device"] == "0"
    assert agent.advanced_configuration["opencl_devices"] == "0,1"
    assert agent.advanced_configuration["enable_additional_hash_types"] is True
    assert agent.token.startswith("csa_")


@pytest.mark.asyncio
async def test_register_agent_forbidden(
    async_client: AsyncClient, db_session: AsyncSession, user_factory: UserFactory
) -> None:
    user = user_factory.build()
    user.is_superuser = False
    user.role = UserRole.ANALYST
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    token = create_access_token(user.id)
    cookies = {"access_token": token}
    form_data = {
        "host_name": "webreg-agent-2",
        "operating_system": "linux",
        "client_signature": "sig-webreg-456",
    }
    resp = await async_client.post(
        "/api/v1/web/agents", json=form_data, cookies=cookies
    )
    assert resp.status_code == codes.FORBIDDEN
    assert "Not authorized" in resp.text or "403" in resp.text
    agent = (
        await db_session.execute(
            select(Agent).where(Agent.client_signature == "sig-webreg-456")
        )
    ).scalar_one_or_none()
    assert agent is None


@pytest.mark.asyncio
async def test_register_agent_validation_error(
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
    # Missing required field: client_signature
    form_data = {
        "host_name": "webreg-agent-3",
        "operating_system": "linux",
    }
    resp = await async_client.post(
        "/api/v1/web/agents", json=form_data, cookies=cookies
    )
    assert resp.status_code in (codes.UNPROCESSABLE_ENTITY, codes.BAD_REQUEST)
    assert "client_signature" in resp.text or "422" in resp.text or "error" in resp.text
    agent = (
        await db_session.execute(
            select(Agent).where(Agent.host_name == "webreg-agent-3")
        )
    ).scalar_one_or_none()
    assert agent is None


@pytest.mark.asyncio
async def test_register_agent_duplicate_signature(
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
    # Create agent with signature
    agent = Agent(
        host_name="existing-agent",
        client_signature="sig-dup-123",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_999_testtoken",
        devices=["GPU0"],
        enabled=True,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    # Try to register another with same signature
    form_data = {
        "host_name": "webreg-agent-4",
        "operating_system": "linux",
        "client_signature": "sig-dup-123",
    }
    resp = await async_client.post(
        "/api/v1/web/agents", json=form_data, cookies=cookies
    )
    # Should succeed (200 OK)
    assert resp.status_code == codes.OK
    # Should create a second agent with the same signature
    agents = (
        (
            await db_session.execute(
                select(Agent).where(Agent.client_signature == "sig-dup-123")
            )
        )
        .scalars()
        .all()
    )
    assert len(agents) == 2
    assert all(a.client_signature == "sig-dup-123" for a in agents)


@pytest.mark.asyncio
async def test_agent_hardware_fragment(
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
        host_name="hardware-agent-1",
        client_signature="sig-hw-123",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_10_testtoken",
        devices=["NVIDIA GTX 1080", "AMD RX 6800"],
        enabled=True,
        advanced_configuration={
            "backend_device": "1,2",
            "opencl_devices": "GPU,CPU",
            "use_native_hashcat": True,
            "enable_additional_hash_types": True,
            "hwmon_temp_abort": 90,
            "agent_update_interval": 15,
        },
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    cookies = {"access_token": token}
    resp = await async_client.get(
        f"/api/v1/web/agents/{agent.id}/hardware", cookies=cookies
    )
    assert resp.status_code == codes.OK
    data = resp.json()
    assert data["host_name"] == "hardware-agent-1"
    assert "NVIDIA GTX 1080" in data["devices"]
    assert "AMD RX 6800" in data["devices"]
    assert data["advanced_configuration"]["backend_device"] == "1,2"
    assert data["advanced_configuration"]["opencl_devices"] == "GPU,CPU"
    assert data["advanced_configuration"]["use_native_hashcat"] is True
    assert data["advanced_configuration"]["enable_additional_hash_types"] is True
    assert data["advanced_configuration"]["hwmon_temp_abort"] == 90
    assert data["advanced_configuration"]["agent_update_interval"] == 15
    assert data["operating_system"] == "linux"
    assert data["state"] == "active"


@pytest.mark.asyncio
async def test_agent_capabilities_endpoint(
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
    # Use pre-seeded hash types from reset_db_and_seed_hash_types
    md5 = await db_session.execute(select(HashType).where(HashType.id == 0))
    sha1 = await db_session.execute(select(HashType).where(HashType.id == 100))
    ht1 = md5.scalar_one()
    ht2 = sha1.scalar_one()
    # Create agent
    agent = Agent(
        host_name="cap-agent-1",
        client_signature="sig-cap-123",
        state=AgentState.active,
        operating_system=OperatingSystemEnum.linux,
        token="csa_5_testtoken",
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
        hash_type_id=ht2.id,
        runtime=150,
        hash_speed=500000.0,
        device="NVIDIA RTX 3090",
        created_at=now,
    )
    db_session.add_all([b1, b2])
    await db_session.commit()
    # Call the endpoint
    cookies = {"access_token": token}
    resp = await async_client.get(
        f"/api/v1/web/agents/{agent.id}/capabilities", cookies=cookies
    )
    assert resp.status_code == codes.OK
    data = resp.json()
    assert data["agent_id"] == agent.id
    assert "capabilities" in data
    caps = data["capabilities"]
    assert isinstance(caps, list)
    # Should have two capabilities (one per hash type)
    hash_type_ids = {c["hash_type_id"] for c in caps}
    assert ht1.id in hash_type_ids
    assert ht2.id in hash_type_ids
    for cap in caps:
        assert "hash_type_name" in cap
        assert "category" in cap
        assert "speed" in cap
        assert "devices" in cap
        assert isinstance(cap["devices"], list)
        for dev in cap["devices"]:
            assert "device" in dev
            assert "hash_speed" in dev
            assert "runtime" in dev
            assert "created_at" in dev
