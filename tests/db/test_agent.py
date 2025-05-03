import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent import Agent, AgentState
from app.models.operating_system import OSName
from tests.factories.agent_factory import AgentFactory
from tests.factories.operating_system_factory import OperatingSystemFactory


@pytest.mark.asyncio
async def test_create_agent_minimal(
    agent_factory: "AgentFactory",
    operating_system_factory: "OperatingSystemFactory",
    db_session: AsyncSession,
) -> None:
    from tests.factories.user_factory import UserFactory

    user = UserFactory.build()
    db_session.add(user)
    await db_session.commit()
    operating_system = operating_system_factory.build()
    db_session.add(operating_system)
    await db_session.commit()
    agent = agent_factory.build(
        operating_system_id=operating_system.id, user_id=user.id
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    assert agent.id is not None
    assert agent.host_name.startswith("host")
    assert agent.state == AgentState.active
    assert agent.operating_system_id == operating_system.id
    assert str(agent.user_id) == str(user.id)


@pytest.mark.asyncio
async def test_agent_enum_enforcement(
    agent_factory: "AgentFactory",
    operating_system_factory: "OperatingSystemFactory",
    db_session: AsyncSession,
) -> None:
    from tests.factories.user_factory import UserFactory

    user = UserFactory.build()
    db_session.add(user)
    await db_session.commit()
    operating_system = operating_system_factory.build()
    db_session.add(operating_system)
    await db_session.commit()
    agent = agent_factory.build(
        operating_system_id=operating_system.id, user_id=user.id, state="notastate"
    )
    db_session.add(agent)
    with pytest.raises(sqlalchemy.exc.StatementError):
        await db_session.commit()


@pytest.mark.asyncio
async def test_agent_update_and_delete(
    agent_factory: "AgentFactory",
    operating_system_factory: "OperatingSystemFactory",
    db_session: AsyncSession,
) -> None:
    from tests.factories.user_factory import UserFactory

    user = UserFactory.build()
    db_session.add(user)
    await db_session.commit()
    os = operating_system_factory.build(
        name=OSName.darwin, cracker_command="hashcat -m 1400"
    )
    db_session.add(os)
    await db_session.commit()
    agent = agent_factory.build(
        operating_system_id=os.id, user_id=user.id, state=AgentState.disabled
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    agent.state = AgentState.active
    await db_session.commit()
    await db_session.refresh(agent)
    assert agent.state == AgentState.active
    await db_session.delete(agent)
    await db_session.commit()
    result = await db_session.get(Agent, agent.id)
    assert result is None
