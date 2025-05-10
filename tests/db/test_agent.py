import pytest
import sqlalchemy
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent import Agent, AgentState
from app.models.operating_system import OSName
from tests.factories.agent_factory import AgentFactory
from tests.factories.operating_system_factory import OperatingSystemFactory


@pytest.fixture(autouse=True)
def set_async_sessions(db_session: AsyncSession) -> None:
    OperatingSystemFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session


@pytest.mark.asyncio
async def test_create_agent_minimal(
    agent_factory: "AgentFactory",
    db_session: AsyncSession,
) -> None:
    os = await OperatingSystemFactory.create_async()
    agent = await agent_factory.create_async(operating_system_id=os.id)
    assert agent.id is not None
    assert agent.host_name.startswith("host")
    assert agent.state == AgentState.active
    assert agent.operating_system_id == os.id


@pytest.mark.asyncio
async def test_agent_enum_enforcement(
    agent_factory: "AgentFactory",
    db_session: AsyncSession,
) -> None:
    os = await OperatingSystemFactory.create_async(name=OSName.linux)
    with pytest.raises(sqlalchemy.exc.DBAPIError):
        await agent_factory.create_async(operating_system_id=os.id, state="notastate")


@pytest.mark.asyncio
async def test_agent_update_and_delete(
    agent_factory: "AgentFactory",
    db_session: AsyncSession,
) -> None:
    os = await OperatingSystemFactory.create_async(
        name=OSName.darwin, cracker_command="hashcat -m 1400"
    )
    agent = await agent_factory.create_async(
        operating_system_id=os.id, state=AgentState.stopped
    )
    agent.state = AgentState.active
    await db_session.commit()
    await db_session.delete(agent)
    await db_session.commit()
    result = await db_session.get(Agent, agent.id)
    assert result is None
