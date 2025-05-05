from http import HTTPStatus
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.models.agent import Agent, AgentState
from app.models.operating_system import OperatingSystem, OSName
from tests.factories.agent_factory import AgentFactory
from tests.factories.operating_system_factory import OperatingSystemFactory


@pytest.mark.asyncio
async def test_agent_registration_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create a minimal OS
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    payload = {
        "signature": "test-signature-123",
        "hostname": "test-agent-01",
        "agent_type": "physical",
        "operating_system_id": str(os.id),
    }
    response = await async_client.post("/api/v1/client/agents/register", json=payload)
    assert response.status_code == HTTPStatus.CREATED
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
    assert response.status_code == HTTPStatus.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_agent_registration_invalid_type(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create a minimal OS
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    payload = {
        "signature": "test-signature-123",
        "hostname": "test-agent-01",
        "agent_type": "invalid_type",
        "operating_system_id": str(os.id),
    }
    response = await async_client.post("/api/v1/client/agents/register", json=payload)
    # Should fail with 422 or 400 due to invalid enum value
    assert response.status_code in (
        HTTPStatus.BAD_REQUEST,
        HTTPStatus.UNPROCESSABLE_ENTITY,
    )


@pytest.mark.asyncio
async def test_agent_heartbeat_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Register agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    reg_payload = {
        "signature": "heartbeat-test-signature",
        "hostname": "heartbeat-agent",
        "agent_type": "physical",
        "operating_system_id": str(os.id),
    }
    reg_resp = await async_client.post(
        "/api/v1/client/agents/register", json=reg_payload
    )
    assert reg_resp.status_code == HTTPStatus.CREATED
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
    assert resp.status_code == HTTPStatus.NO_CONTENT


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
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


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
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_agent_heartbeat_invalid_state(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Register agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    reg_payload = {
        "signature": "heartbeat-test-signature2",
        "hostname": "heartbeat-agent2",
        "agent_type": "physical",
        "operating_system_id": str(os.id),
    }
    reg_resp = await async_client.post(
        "/api/v1/client/agents/register", json=reg_payload
    )
    assert reg_resp.status_code == HTTPStatus.CREATED
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
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_agent_state_update_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Register agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    reg_payload = {
        "signature": "state-test-signature",
        "hostname": "state-agent",
        "agent_type": "physical",
        "operating_system_id": str(os.id),
    }
    reg_resp = await async_client.post(
        "/api/v1/client/agents/register", json=reg_payload
    )
    assert reg_resp.status_code == HTTPStatus.CREATED
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
    assert resp.status_code == HTTPStatus.NO_CONTENT


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
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


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
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_agent_state_update_invalid_state(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Register agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    reg_payload = {
        "signature": "state-test-signature2",
        "hostname": "state-agent2",
        "agent_type": "physical",
        "operating_system_id": str(os.id),
    }
    reg_resp = await async_client.post(
        "/api/v1/client/agents/register", json=reg_payload
    )
    assert reg_resp.status_code == HTTPStatus.CREATED
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
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_agent_submit_benchmark_success(
    async_client: AsyncClient,
    db_session: AsyncSession,
    agent_factory: AgentFactory,
    operating_system_factory: OperatingSystemFactory,
) -> None:
    os = operating_system_factory.build()
    db_session.add(os)
    await db_session.commit()
    agent = agent_factory.build(operating_system=os, user_id=None)
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
    assert response.status_code == HTTPStatus.NO_CONTENT


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
    assert response.status_code in {HTTPStatus.FORBIDDEN, HTTPStatus.UNAUTHORIZED}


@pytest.mark.asyncio
async def test_agent_submit_error_success(
    async_client: AsyncClient,
    db_session: AsyncSession,
    agent_factory: AgentFactory,
    operating_system_factory: OperatingSystemFactory,
) -> None:
    os = operating_system_factory.build()
    db_session.add(os)
    await db_session.commit()
    agent = agent_factory.build(operating_system=os, user_id=None)
    db_session.add(agent)
    await db_session.commit()
    token = agent.token
    agent_id = agent.id
    headers = {"Authorization": f"Bearer {token}"}
    payload = {
        "message": "Test error message",
        "severity": "major",
        "metadata": {"foo": "bar"},
    }
    response = await async_client.post(
        f"/api/v1/agents/{agent_id}/submit_error", json=payload, headers=headers
    )
    assert response.status_code == HTTPStatus.NO_CONTENT
    result = await db_session.execute(select(Agent).where(Agent.id == agent_id))
    updated_agent = result.scalar_one()
    assert updated_agent.state == AgentState.error


@pytest.mark.asyncio
async def test_agent_shutdown_success(
    async_client: AsyncClient,
    db_session: AsyncSession,
    agent_factory: AgentFactory,
    operating_system_factory: OperatingSystemFactory,
) -> None:
    os = operating_system_factory.build()
    db_session.add(os)
    await db_session.commit()
    agent = agent_factory.build(operating_system=os, user_id=None)
    db_session.add(agent)
    await db_session.commit()
    token = agent.token
    agent_id = agent.id
    headers = {"Authorization": f"Bearer {token}"}
    response = await async_client.post(
        f"/api/v1/agents/{agent_id}/shutdown", headers=headers
    )
    assert response.status_code == HTTPStatus.NO_CONTENT
    result = await db_session.execute(select(Agent).where(Agent.id == agent_id))
    updated_agent = result.scalar_one()
    assert updated_agent.state == AgentState.disabled


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
    assert response.status_code in {HTTPStatus.FORBIDDEN, HTTPStatus.UNAUTHORIZED}


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
    assert response.status_code in {HTTPStatus.FORBIDDEN, HTTPStatus.UNAUTHORIZED}
