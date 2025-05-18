from datetime import UTC, datetime

import pytest
from httpx import AsyncClient, codes
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.models.agent import Agent, AgentState, AgentType, OperatingSystemEnum
from app.models.cracker_binary import CrackerBinary
from tests.factories.agent_factory import AgentFactory


@pytest.mark.asyncio
async def test_agent_registration_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create a minimal OS
    payload = {
        "signature": "test-signature-123",
        "hostname": "test-agent-01",
        "agent_type": AgentType.physical.value,
        "operating_system": "linux",
    }
    response = await async_client.post("/api/v1/client/agents/register", json=payload)
    if response.status_code != codes.CREATED:
        print("Registration response:", response.status_code, response.text)
    assert response.status_code == codes.CREATED
    data = response.json()
    assert "agent_id" in data
    assert data["token"].startswith("csa_")


@pytest.mark.asyncio
async def test_agent_registration_missing_fields(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    payload = {
        "signature": "test-signature-123"
        # Missing hostname, agent_type, and operating_system_id
    }
    response = await async_client.post("/api/v1/client/agents/register", json=payload)
    assert response.status_code == codes.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_agent_heartbeat_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Register agent
    reg_payload = {
        "signature": "heartbeat-test-signature",
        "hostname": "heartbeat-agent",
        "agent_type": AgentType.physical.value,
        "operating_system": "linux",
    }
    reg_resp = await async_client.post(
        "/api/v1/client/agents/register", json=reg_payload
    )
    if reg_resp.status_code != codes.CREATED:
        print("Registration response:", reg_resp.status_code, reg_resp.text)
    assert reg_resp.status_code == codes.CREATED
    token = reg_resp.json()["token"]
    # Send heartbeat
    heartbeat_payload = {"state": "active"}
    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.post(
        "/api/v1/client/agents/heartbeat", json=heartbeat_payload, headers=headers
    )
    assert resp.status_code == codes.NO_CONTENT


@pytest.mark.asyncio
async def test_agent_heartbeat_invalid_token(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    heartbeat_payload = {"state": "active"}
    headers = {
        "Authorization": "Bearer csa_invalidtoken",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.post(
        "/api/v1/client/agents/heartbeat", json=heartbeat_payload, headers=headers
    )
    assert resp.status_code == codes.UNAUTHORIZED


@pytest.mark.asyncio
async def test_agent_heartbeat_missing_user_agent(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    heartbeat_payload = {"state": "active"}
    headers = {
        "Authorization": "Bearer csa_invalidtoken",
    }
    resp = await async_client.post(
        "/api/v1/client/agents/heartbeat", json=heartbeat_payload, headers=headers
    )
    # v1 does not require User-Agent; should return 401 for bad Authorization
    assert resp.status_code == codes.UNAUTHORIZED


@pytest.mark.asyncio
async def test_agent_heartbeat_invalid_state(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Register agent
    reg_payload = {
        "signature": "heartbeat-test-signature2",
        "hostname": "heartbeat-agent2",
        "agent_type": AgentType.physical.value,
        "operating_system": "linux",
    }
    reg_resp = await async_client.post(
        "/api/v1/client/agents/register", json=reg_payload
    )
    if reg_resp.status_code != codes.CREATED:
        print("Registration response:", reg_resp.status_code, reg_resp.text)
    assert reg_resp.status_code == codes.CREATED
    token = reg_resp.json()["token"]
    # Send heartbeat with invalid state
    heartbeat_payload = {"state": "not_a_state"}
    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.post(
        "/api/v1/client/agents/heartbeat", json=heartbeat_payload, headers=headers
    )
    assert resp.status_code == codes.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_agent_state_update_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Register agent
    reg_payload = {
        "signature": "state-test-signature",
        "hostname": "state-agent",
        "agent_type": AgentType.physical.value,
        "operating_system": "linux",
    }
    reg_resp = await async_client.post(
        "/api/v1/client/agents/register", json=reg_payload
    )
    if reg_resp.status_code != codes.CREATED:
        print("Registration response:", reg_resp.status_code, reg_resp.text)
    assert reg_resp.status_code == codes.CREATED
    token = reg_resp.json()["token"]
    # Update state
    state_payload = {"state": "active"}
    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.post(
        "/api/v1/client/agents/state", json=state_payload, headers=headers
    )
    assert resp.status_code == codes.NO_CONTENT


@pytest.mark.asyncio
async def test_agent_state_update_invalid_token(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    state_payload = {"state": "active"}
    headers = {
        "Authorization": "Bearer csa_invalidtoken",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.post(
        "/api/v1/client/agents/state", json=state_payload, headers=headers
    )
    assert resp.status_code == codes.UNAUTHORIZED


@pytest.mark.asyncio
async def test_agent_state_update_missing_user_agent(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    state_payload = {"state": "active"}
    headers = {
        "Authorization": "Bearer csa_invalidtoken",
    }
    resp = await async_client.post(
        "/api/v1/client/agents/state", json=state_payload, headers=headers
    )
    # v1 does not require User-Agent; should return 401 for bad Authorization
    assert resp.status_code == codes.UNAUTHORIZED


@pytest.mark.asyncio
async def test_agent_state_update_invalid_state(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Register agent
    reg_payload = {
        "signature": "state-test-signature2",
        "hostname": "state-agent2",
        "agent_type": AgentType.physical.value,
        "operating_system": "linux",
    }
    reg_resp = await async_client.post(
        "/api/v1/client/agents/register", json=reg_payload
    )
    if reg_resp.status_code != codes.CREATED:
        print("Registration response:", reg_resp.status_code, reg_resp.text)
    assert reg_resp.status_code == codes.CREATED
    token = reg_resp.json()["token"]
    # Update state with invalid value
    state_payload = {"state": "not_a_state"}
    headers = {
        "Authorization": f"Bearer {token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.post(
        "/api/v1/client/agents/state", json=state_payload, headers=headers
    )
    assert resp.status_code == codes.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_agent_submit_benchmark_success(
    async_client: AsyncClient,
    db_session: AsyncSession,
    agent_factory: AgentFactory,
) -> None:
    agent = agent_factory.build(
        operating_system=OperatingSystemEnum.linux, user_id=None
    )
    db_session.add(agent)
    await db_session.commit()
    token = agent.token
    agent_id = agent.id
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "hashcat_benchmarks": [
            {"hash_type": 0, "runtime": 1234, "hash_speed": 56789.0, "device": 0}
        ]
    }
    response = await async_client.post(
        f"/api/v1/agents/{agent_id}/submit_benchmark", json=payload, headers=headers
    )
    assert response.status_code == codes.NO_CONTENT


@pytest.mark.asyncio
async def test_agent_submit_benchmark_invalid_token(
    async_client: AsyncClient,
    agent_factory: AgentFactory,
) -> None:
    agent = agent_factory.build()
    agent_id = agent.id
    payload = {
        "hashcat_benchmarks": [
            {"hash_type": 1000, "runtime": 1234, "hash_speed": 56789.0, "device": 0}
        ]
    }
    headers = {"Authorization": "Bearer invalidtoken"}
    response = await async_client.post(
        f"/api/v1/agents/{agent_id}/submit_benchmark", json=payload, headers=headers
    )
    assert response.status_code in {codes.FORBIDDEN, codes.UNAUTHORIZED}


@pytest.mark.asyncio
async def test_agent_submit_error_success(
    async_client: AsyncClient,
    db_session: AsyncSession,
    agent_factory: AgentFactory,
) -> None:
    agent = agent_factory.build(
        operating_system=OperatingSystemEnum.linux, user_id=None
    )
    db_session.add(agent)
    await db_session.commit()
    token = agent.token
    agent_id = agent.id
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "message": "Test error message",
        "severity": "major",
        "metadata": {"foo": "bar"},
        "agent_id": agent_id,
    }
    response = await async_client.post(
        f"/api/v1/agents/{agent_id}/submit_error", json=payload, headers=headers
    )
    assert response.status_code == codes.NO_CONTENT
    result = await db_session.execute(select(Agent).where(Agent.id == agent_id))
    updated_agent = result.scalar_one()
    assert updated_agent.state == AgentState.error


@pytest.mark.asyncio
async def test_agent_shutdown_success(
    async_client: AsyncClient,
    db_session: AsyncSession,
    agent_factory: AgentFactory,
) -> None:
    agent = agent_factory.build(
        operating_system=OperatingSystemEnum.linux, user_id=None
    )
    db_session.add(agent)
    await db_session.commit()
    token = agent.token
    agent_id = agent.id
    headers = {"Authorization": f"Bearer {token}"}
    response = await async_client.post(
        f"/api/v1/agents/{agent_id}/shutdown", headers=headers
    )
    assert response.status_code == codes.NO_CONTENT
    result = await db_session.execute(select(Agent).where(Agent.id == agent_id))
    updated_agent = result.scalar_one()
    assert updated_agent.state == AgentState.stopped


@pytest.mark.asyncio
async def test_agent_shutdown_invalid_token(
    async_client: AsyncClient,
    agent_factory: AgentFactory,
) -> None:
    agent = agent_factory.build()
    agent_id = agent.id
    headers = {"Authorization": "Bearer invalidtoken"}
    response = await async_client.post(
        f"/api/v1/agents/{agent_id}/shutdown", headers=headers
    )
    assert response.status_code in {codes.FORBIDDEN, codes.UNAUTHORIZED}


@pytest.mark.asyncio
async def test_agent_submit_error_invalid_token(
    async_client: AsyncClient,
    agent_factory: AgentFactory,
) -> None:
    agent = agent_factory.build()
    agent_id = agent.id
    headers = {"Authorization": "Bearer invalidtoken"}
    response = await async_client.post(
        f"/api/v1/agents/{agent_id}/submit_error", headers=headers
    )
    assert response.status_code in {codes.FORBIDDEN, codes.UNAUTHORIZED}


@pytest.mark.asyncio
async def test_get_agent_configuration_happy_path(
    async_client: AsyncClient, db_session: AsyncSession, agent_factory: AgentFactory
) -> None:
    agent = await agent_factory.create_async(operating_system=OperatingSystemEnum.linux)
    token = agent.token
    headers = {"Authorization": f"Bearer {token}"}
    response = await async_client.get("/api/v1/client/configuration", headers=headers)
    assert response.status_code == codes.OK
    data = response.json()
    assert "config" in data
    assert "api_version" in data
    assert data["api_version"] == 1
    # Validate config fields
    config = data["config"]
    assert "agent_update_interval" in config
    assert "use_native_hashcat" in config
    assert "enable_additional_hash_types" in config


@pytest.mark.asyncio
async def test_get_agent_configuration_unauthorized(async_client: AsyncClient) -> None:
    response = await async_client.get("/api/v1/client/configuration")
    assert response.status_code in (codes.UNAUTHORIZED, codes.UNPROCESSABLE_ENTITY)
    data = response.json()
    assert "detail" in data


@pytest.mark.asyncio
async def test_get_agent_configuration_no_advanced_config(
    async_client: AsyncClient, db_session: AsyncSession, agent_factory: AgentFactory
) -> None:
    agent = await agent_factory.create_async(operating_system=OperatingSystemEnum.linux)
    agent.advanced_configuration = None
    await db_session.commit()
    token = agent.token
    headers = {"Authorization": f"Bearer {token}"}
    response = await async_client.get("/api/v1/client/configuration", headers=headers)
    assert response.status_code == codes.OK
    data = response.json()
    assert "config" in data
    assert "api_version" in data
    assert data["api_version"] == 1
    config = data["config"]
    # Should return default values
    assert "agent_update_interval" in config
    assert "use_native_hashcat" in config
    assert "enable_additional_hash_types" in config


@pytest.mark.asyncio
async def test_agent_authenticate_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Register agent
    reg_payload = {
        "signature": "auth-test-signature",
        "hostname": "auth-agent",
        "agent_type": AgentType.physical.value,
        "operating_system": "linux",
    }
    reg_resp = await async_client.post(
        "/api/v1/client/agents/register", json=reg_payload
    )
    assert reg_resp.status_code == codes.CREATED
    token = reg_resp.json()["token"]
    headers = {"Authorization": f"Bearer {token}"}
    resp = await async_client.get("/api/v1/client/authenticate", headers=headers)
    assert resp.status_code == codes.OK
    data = resp.json()
    assert data["authenticated"] is True
    assert isinstance(data["agent_id"], int)


@pytest.mark.asyncio
async def test_agent_authenticate_unauthorized(async_client: AsyncClient) -> None:
    headers = {"Authorization": "Bearer csa_invalidtoken"}
    resp = await async_client.get("/api/v1/client/authenticate", headers=headers)
    assert resp.status_code == codes.UNAUTHORIZED
    data = resp.json()
    assert data["error"] == "Bad credentials"


@pytest.mark.asyncio
async def test_cracker_update_available(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Insert a newer CrackerBinary for linux
    cb = CrackerBinary(
        operating_system=OperatingSystemEnum.linux,
        version="7.1.0",
        download_url="https://example.com/hashcat-7.1.0.tar.gz",
        exec_name="hashcat",
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )
    db_session.add(cb)
    await db_session.commit()
    reg_payload = {
        "signature": "update-test-signature",
        "hostname": "update-agent",
        "agent_type": AgentType.physical.value,
        "operating_system": "linux",
    }
    reg_resp = await async_client.post(
        "/api/v1/client/agents/register", json=reg_payload
    )
    assert reg_resp.status_code == codes.CREATED
    token = reg_resp.json()["token"]
    headers = {"Authorization": f"Bearer {token}"}
    params = {"version": "7.0.0", "operating_system": "linux"}
    resp = await async_client.get(
        "/api/v1/client/crackers/check_for_cracker_update",
        headers=headers,
        params=params,
    )
    assert resp.status_code == codes.OK
    data = resp.json()
    assert data["available"] is True
    assert data["latest_version"] == "7.1.0"
    assert data["download_url"] == "https://example.com/hashcat-7.1.0.tar.gz"
    assert data["exec_name"] == "hashcat"
    assert "update" in data["message"].lower()


@pytest.mark.asyncio
async def test_cracker_update_up_to_date(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Insert a CrackerBinary with the same version as the agent
    cb = CrackerBinary(
        operating_system=OperatingSystemEnum.linux,
        version="7.1.0",
        download_url="https://example.com/hashcat-7.1.0.tar.gz",
        exec_name="hashcat",
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )
    db_session.add(cb)
    await db_session.commit()
    reg_payload = {
        "signature": "uptodate-test-signature",
        "hostname": "uptodate-agent",
        "agent_type": AgentType.physical.value,
        "operating_system": "linux",
    }
    reg_resp = await async_client.post(
        "/api/v1/client/agents/register", json=reg_payload
    )
    assert reg_resp.status_code == codes.CREATED
    token = reg_resp.json()["token"]
    headers = {"Authorization": f"Bearer {token}"}
    params = {"version": "7.1.0", "operating_system": "linux"}
    resp = await async_client.get(
        "/api/v1/client/crackers/check_for_cracker_update",
        headers=headers,
        params=params,
    )
    assert resp.status_code == codes.OK
    data = resp.json()
    assert data["available"] is False
    assert data["latest_version"] == "7.1.0"
    assert data["exec_name"] == "hashcat"
    assert data["download_url"] is None
    assert "up to date" in data["message"].lower()
