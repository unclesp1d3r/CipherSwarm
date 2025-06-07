from collections.abc import AsyncGenerator
from http import HTTPStatus
from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory


@pytest.mark.asyncio
async def test_attack_live_updates_toggle(
    async_client: AsyncClient,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    hash_list_factory: HashListFactory,
    project_factory: ProjectFactory,
    db_session: AsyncSession,
) -> None:
    # Setup: create project, hash list, campaign, attack
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await attack_factory.create_async(
        name="LiveUpdatesTest",
        attack_mode="dictionary",
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
    )
    # Toggle (should disable)
    resp = await async_client.post(
        f"/api/v1/web/attacks/{attack.id}/disable_live_updates"
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert "message" in data
    # Explicit enable
    resp2 = await async_client.post(
        f"/api/v1/web/attacks/{attack.id}/disable_live_updates?enabled=true"
    )
    assert resp2.status_code == HTTPStatus.OK
    data2 = resp2.json()
    assert "message" in data2
    # Explicit disable
    resp3 = await async_client.post(
        f"/api/v1/web/attacks/{attack.id}/disable_live_updates?enabled=false"
    )
    assert resp3.status_code == HTTPStatus.OK
    data3 = resp3.json()
    assert "message" in data3
    # Not found
    resp4 = await async_client.post("/api/v1/web/attacks/999999/disable_live_updates")
    assert resp4.status_code == HTTPStatus.NOT_FOUND
    data4 = resp4.json()
    assert "detail" in data4 or "error" in data4


@pytest.mark.asyncio
async def test_sse_campaigns_feed(authenticated_async_client: AsyncClient) -> None:
    """Test /api/v1/web/live/campaigns SSE endpoint basic connect and broadcast."""

    # Mock the event service to avoid complex async testing
    with patch("app.api.v1.endpoints.web.live.get_event_service") as mock_get_service:
        mock_service = AsyncMock()
        mock_listener = AsyncMock()

        # Create a proper async generator mock
        async def mock_get_events() -> AsyncGenerator[str]:
            yield 'data: {"trigger": "refresh", "target": "campaigns"}\n\n'

        # Set the mock to return the async generator function, not call it
        mock_listener.get_events = mock_get_events
        mock_service.create_listener.return_value = mock_listener
        mock_get_service.return_value = mock_service

        # Test SSE connection
        response = await authenticated_async_client.get("/api/v1/web/live/campaigns")
        assert response.status_code == HTTPStatus.OK
        assert response.headers.get("content-type") == "text/plain; charset=utf-8"

        # Verify the event service was called correctly
        mock_service.create_listener.assert_called_once_with(
            topics={"campaigns"}, project_id=None
        )


@pytest.mark.asyncio
async def test_sse_agents_feed(authenticated_async_client: AsyncClient) -> None:
    """Test /api/v1/web/live/agents SSE endpoint basic connect and broadcast."""

    # Mock the event service to avoid complex async testing
    with patch("app.api.v1.endpoints.web.live.get_event_service") as mock_get_service:
        mock_service = AsyncMock()
        mock_listener = AsyncMock()

        # Create a proper async generator mock
        async def mock_get_events() -> AsyncGenerator[str]:
            yield 'data: {"trigger": "refresh", "target": "agents"}\n\n'

        # Set the mock to return the async generator function, not call it
        mock_listener.get_events = mock_get_events
        mock_service.create_listener.return_value = mock_listener
        mock_get_service.return_value = mock_service

        # Test SSE connection
        response = await authenticated_async_client.get("/api/v1/web/live/agents")
        assert response.status_code == HTTPStatus.OK
        assert response.headers.get("content-type") == "text/plain; charset=utf-8"

        # Verify the event service was called correctly
        mock_service.create_listener.assert_called_once_with(
            topics={"agents"}, project_id=None
        )


@pytest.mark.asyncio
async def test_sse_toasts_feed(authenticated_async_client: AsyncClient) -> None:
    """Test /api/v1/web/live/toasts SSE endpoint basic connect and broadcast."""

    # Mock the event service to avoid complex async testing
    with patch("app.api.v1.endpoints.web.live.get_event_service") as mock_get_service:
        mock_service = AsyncMock()
        mock_listener = AsyncMock()

        # Create a proper async generator mock
        async def mock_get_events() -> AsyncGenerator[str]:
            yield 'data: {"trigger": "Test toast", "target": "toasts"}\n\n'

        # Set the mock to return the async generator function, not call it
        mock_listener.get_events = mock_get_events
        mock_service.create_listener.return_value = mock_listener
        mock_get_service.return_value = mock_service

        # Test SSE connection
        response = await authenticated_async_client.get("/api/v1/web/live/toasts")
        assert response.status_code == HTTPStatus.OK
        assert response.headers.get("content-type") == "text/plain; charset=utf-8"

        # Verify the event service was called correctly
        mock_service.create_listener.assert_called_once_with(
            topics={"toasts"}, project_id=None
        )
