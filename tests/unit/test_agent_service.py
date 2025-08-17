"""
Unit tests for agent service.
"""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.agent_service import (
    can_handle_hash_type,
    get_agent_benchmark_summary_service,
    get_agent_by_id_service,
    heartbeat_agent_service,
    list_agents_service,
    register_agent_service,
    toggle_agent_enabled_service,
    trigger_agent_benchmark_service,
    update_agent_state_service,
    validate_presigned_url_service,
)
from app.models.agent import AgentState, AgentType, OperatingSystemEnum
from app.schemas.agent import (
    AgentHeartbeatRequest,
    AgentRegisterRequest,
    AgentStateUpdateRequest,
)
from tests.factories.agent_factory import AgentFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_register_agent_service_success(db_session: AsyncSession) -> None:
    """Test successful agent registration."""
    # Create agent registration request
    agent_data = AgentRegisterRequest(
        signature="test-agent-v1.0",
        hostname="test-host",
        operating_system=OperatingSystemEnum.linux,
        agent_type=AgentType.physical,
    )

    # Register agent
    result = await register_agent_service(agent_data, db_session)

    assert result.agent_id > 0
    assert result.token.startswith("csa_")
    assert len(result.token) > 10  # Should have reasonable length


@pytest.mark.asyncio
async def test_get_agent_by_id_service_success(db_session: AsyncSession) -> None:
    """Test successful agent retrieval by ID."""
    # Set factory sessions
    AgentFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    await ProjectFactory.create_async()
    agent = await AgentFactory.create_async()

    # Get agent
    result = await get_agent_by_id_service(agent.id, db_session)

    assert result is not None
    assert result.id == agent.id
    assert result.host_name == agent.host_name


@pytest.mark.asyncio
async def test_get_agent_by_id_service_not_found(db_session: AsyncSession) -> None:
    """Test agent retrieval with non-existent ID."""
    result = await get_agent_by_id_service(999999, db_session)
    assert result is None


@pytest.mark.asyncio
async def test_list_agents_service_success(db_session: AsyncSession) -> None:
    """Test successful agent listing."""
    # Set factory sessions
    AgentFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    await ProjectFactory.create_async()

    # Create test agents
    await AgentFactory.create_async(
        host_name="agent-1",
        state=AgentState.active,
    )
    await AgentFactory.create_async(
        host_name="agent-2",
        state=AgentState.pending,
    )

    # List agents
    result, total = await list_agents_service(db_session)

    assert len(result) >= 2  # May have other agents from other tests
    assert total >= 2

    # Check that our agents are in the results
    hostnames = {agent.host_name for agent in result}
    assert "agent-1" in hostnames
    assert "agent-2" in hostnames


@pytest.mark.asyncio
async def test_list_agents_service_with_search(db_session: AsyncSession) -> None:
    """Test agent listing with search filtering."""
    # Set factory sessions
    AgentFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    await ProjectFactory.create_async()

    # Create test agents with unique hostnames
    await AgentFactory.create_async(
        host_name="production-server-unique-01",
    )
    await AgentFactory.create_async(
        host_name="test-machine-unique-02",
    )

    # Search for production servers
    result, total = await list_agents_service(
        db_session, search="production-server-unique"
    )

    assert len(result) == 1
    assert total == 1
    assert result[0].host_name == "production-server-unique-01"


@pytest.mark.asyncio
async def test_update_agent_state_service_success(db_session: AsyncSession) -> None:
    """Test successful agent state update."""
    # Set factory sessions
    AgentFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(
        state=AgentState.pending,
    )

    # Update agent state
    update_data = AgentStateUpdateRequest(state=AgentState.active)
    await update_agent_state_service(update_data, db_session, f"Bearer {agent.token}")

    # Query the agent from database to check state
    refreshed_agent = await get_agent_by_id_service(agent.id, db_session)
    assert refreshed_agent.state == AgentState.active


@pytest.mark.asyncio
@patch("app.core.services.agent_service.get_event_service")
async def test_heartbeat_agent_service_success(
    mock_get_event_service: MagicMock,
    db_session: AsyncSession,
) -> None:
    """Test successful agent heartbeat processing."""
    # Mock event service
    mock_event_service = AsyncMock()
    mock_get_event_service.return_value = mock_event_service

    # Set factory sessions
    AgentFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(
        state=AgentState.active,
    )

    # Create mock request
    mock_request = MagicMock()
    mock_request.headers = {"authorization": f"Bearer {agent.token}"}
    mock_request.client.host = "127.0.0.1"  # Set proper IP address string

    # Create heartbeat request
    heartbeat_data = AgentHeartbeatRequest(
        state=AgentState.active,
    )

    # Process heartbeat - the function returns None, just ensure no exception is raised
    result = await heartbeat_agent_service(
        mock_request, heartbeat_data, db_session, f"Bearer {agent.token}"
    )

    # The function returns None, so just check it completes without error
    assert result is None


@pytest.mark.asyncio
@patch("app.core.services.agent_service.user_can")
async def test_toggle_agent_enabled_service_success(
    mock_user_can: MagicMock, db_session: AsyncSession
) -> None:
    """Test successful agent enable/disable toggle."""
    # Mock authorization to always allow
    mock_user_can.return_value = True

    # Set factory sessions
    AgentFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session
    UserFactory.__async_session__ = db_session

    # Create test data
    await ProjectFactory.create_async()
    user = await UserFactory.create_async()
    agent = await AgentFactory.create_async(
        enabled=True,
    )

    # Toggle agent (disable)
    result = await toggle_agent_enabled_service(agent.id, user, db_session)

    assert result.id == agent.id
    assert result.enabled is False

    # Toggle again (enable)
    result = await toggle_agent_enabled_service(agent.id, user, db_session)

    assert result.id == agent.id
    assert result.enabled is True


@pytest.mark.asyncio
async def test_get_agent_benchmark_summary_service_success(
    db_session: AsyncSession,
) -> None:
    """Test successful agent benchmark summary retrieval."""
    # Set factory sessions
    AgentFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    await ProjectFactory.create_async()
    agent = await AgentFactory.create_async()

    # Get benchmark summary
    result = await get_agent_benchmark_summary_service(agent.id, db_session)

    assert isinstance(result, dict)
    # Should return empty dict since no benchmarks exist
    assert len(result) == 0


@pytest.mark.asyncio
async def test_can_handle_hash_type_success(db_session: AsyncSession) -> None:
    """Test hash type capability check."""
    # Set factory sessions
    AgentFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session

    # Create test data
    await ProjectFactory.create_async()
    agent = await AgentFactory.create_async()

    # Check if agent can handle MD5 (hash_type_id = 0)
    result = await can_handle_hash_type(agent.id, 0, db_session)

    assert isinstance(result, bool)
    # Should return False if no benchmarks exist
    assert result is False


@pytest.mark.asyncio
@patch("app.core.services.agent_service.user_can")
async def test_trigger_agent_benchmark_service_success(
    mock_user_can: MagicMock,
    db_session: AsyncSession,
) -> None:
    """Test successful agent benchmark trigger."""
    # Mock authorization to always allow
    mock_user_can.return_value = True

    # Set factory sessions
    AgentFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session
    UserFactory.__async_session__ = db_session

    # Create test data
    await ProjectFactory.create_async()
    user = await UserFactory.create_async()
    agent = await AgentFactory.create_async(
        state=AgentState.active,
    )

    # Trigger benchmark
    result = await trigger_agent_benchmark_service(agent.id, user, db_session)

    assert result.id == agent.id
    # Agent state should be pending after benchmark trigger
    assert result.state == AgentState.pending


@pytest.mark.asyncio
async def test_test_presigned_url_service_success() -> None:
    """Test presigned URL testing with mock HTTP response."""
    with patch("httpx.AsyncClient.head") as mock_head:
        # Mock successful response
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_head.return_value = mock_response

        result = await validate_presigned_url_service("https://example.com/test-url")

        assert result is True
        mock_head.assert_called_once_with("https://example.com/test-url")


@pytest.mark.asyncio
async def test_test_presigned_url_service_failure() -> None:
    """Test presigned URL testing with failed HTTP response."""
    with patch("httpx.AsyncClient.head") as mock_head:
        # Mock failed response
        mock_response = MagicMock()
        mock_response.status_code = 404
        mock_head.return_value = mock_response

        result = await validate_presigned_url_service("https://example.com/test-url")

        assert result is False


@pytest.mark.asyncio
async def test_test_presigned_url_service_exception() -> None:
    """Test presigned URL testing with HTTP exception."""
    with patch("httpx.AsyncClient.head") as mock_head:
        # Mock HTTP exception
        mock_head.side_effect = Exception("Connection failed")

        result = await validate_presigned_url_service("https://example.com/test-url")

        assert result is False
