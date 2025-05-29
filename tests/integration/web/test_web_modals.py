import pytest
from httpx import AsyncClient, codes
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import create_access_token
from app.models.agent import AgentState
from tests.factories.agent_factory import AgentFactory
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_rule_explanation_modal_json(async_client: AsyncClient) -> None:
    resp = await async_client.get("/api/v1/web/modals/rule_explanation")
    assert resp.status_code == codes.OK
    data = resp.json()
    assert "rule_explanations" in data
    assert isinstance(data["rule_explanations"], list)
    # Check at least one known rule/desc pair
    found = any(
        item["rule"] == "c" and item["desc"] == "Lowercase all characters"
        for item in data["rule_explanations"]
    )
    assert found, "Expected rule 'c' with correct description in response"
    # All items should have 'rule' and 'desc' as strings
    for item in data["rule_explanations"]:
        assert isinstance(item["rule"], str)
        assert isinstance(item["desc"], str)


@pytest.mark.asyncio
async def test_agent_dropdown_modal_json(
    async_client: AsyncClient,
    db_session: AsyncSession,
    agent_factory: AgentFactory,
    user_factory: UserFactory,
) -> None:
    # Create a user and set access_token
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    token = create_access_token(user.id)
    async_client.cookies.set("access_token", token)
    # Create agents
    agent1 = agent_factory.build(custom_label="AlphaAgent", state=AgentState.active)
    agent2 = agent_factory.build(
        custom_label=None, host_name="host-xyz", state=AgentState.stopped
    )
    db_session.add_all([agent1, agent2])
    await db_session.commit()
    # Call endpoint
    resp = await async_client.get("/api/v1/web/modals/agents")
    assert resp.status_code == codes.OK
    data = resp.json()
    assert isinstance(data, list)
    # Should include both agents
    names = [a["display_name"] for a in data]
    states = [a["state"] for a in data]
    assert "AlphaAgent" in names
    assert "host-xyz" in names
    assert "active" in states
    assert "stopped" in states
    # Each item should have id, display_name, state
    for a in data:
        assert "id" in a
        assert "display_name" in a
        assert "state" in a

    # Test auth required
    async_client.cookies.clear()
    resp2 = await async_client.get("/api/v1/web/modals/agents")
    assert resp2.status_code == codes.UNAUTHORIZED
