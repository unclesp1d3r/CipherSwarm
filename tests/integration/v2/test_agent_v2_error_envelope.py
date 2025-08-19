import re
from datetime import UTC, datetime

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.agent_v2_service import agent_v2_service


@pytest.mark.asyncio
async def test_unexpected_error_returns_v2_envelope(
    async_client: AsyncClient, db_session: AsyncSession, monkeypatch: pytest.MonkeyPatch
) -> None:
    """Ensure unexpected exceptions return standardized v2 error envelope."""

    async def boom(*args, **kwargs):  # type: ignore[no-untyped-def]
        raise RuntimeError("kaboom")

    # Patch a v2 endpoint service to raise RuntimeError
    monkeypatch.setattr(
        agent_v2_service,
        "get_agent_info_v2_service",
        boom,
        raising=True,
    )

    # Create an agent and get a token via factory
    from tests.factories.agent_factory import AgentFactory

    agent = await AgentFactory.create_async(token="csa_1_testtokentesttokentesttok")

    headers = {"Authorization": f"Bearer {agent.token}"}

    # Hitting /api/v2/client/agents/me will call the patched service
    resp = await async_client.get("/api/v2/client/agents/me", headers=headers)

    assert resp.status_code == 500
    assert resp.headers.get("content-type", "").startswith("application/json")

    body = resp.json()
    # Validate exact envelope keys/values (timestamp dynamic)
    assert set(body.keys()) == {"error", "message", "details", "timestamp"}
    assert body["error"] == "internal_server_error"
    assert body["message"] == "An unexpected error occurred"
    assert body["details"] is None

    # Validate ISO8601 UTC timestamp
    ts = body["timestamp"]
    # Must parse and be UTC
    dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    assert dt.tzinfo is not None
    assert dt.utcoffset() == datetime.now(UTC).utcoffset()
