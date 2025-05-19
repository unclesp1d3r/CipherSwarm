import pytest
from httpx import AsyncClient, codes
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.models.agent import Agent, AgentState, OperatingSystemEnum
from tests.factories.agent_factory import AgentFactory


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
