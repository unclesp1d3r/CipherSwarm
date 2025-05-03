import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent_error import AgentError, Severity
from tests.factories.agent_error_factory import AgentErrorFactory
from tests.factories.agent_factory import AgentFactory
from tests.factories.task_factory import TaskFactory


@pytest.mark.asyncio
async def test_create_agent_error_minimal(
    agent_error_factory: AgentErrorFactory,
    agent_factory: AgentFactory,
    task_factory: TaskFactory,
    db_session: AsyncSession,
) -> None:
    from tests.factories.attack_factory import AttackFactory
    from tests.factories.user_factory import UserFactory

    user = UserFactory.build()
    db_session.add(user)
    await db_session.commit()
    from tests.factories.operating_system_factory import OperatingSystemFactory

    os = OperatingSystemFactory.build()
    db_session.add(os)
    await db_session.commit()
    agent = agent_factory.build(operating_system_id=os.id, user_id=user.id)
    db_session.add(agent)
    await db_session.commit()
    attack = AttackFactory.build()
    db_session.add(attack)
    await db_session.commit()
    task = task_factory.build(attack_id=attack.id)
    db_session.add(task)
    await db_session.commit()
    agent_error = agent_error_factory.build(agent_id=agent.id, task_id=task.id)
    db_session.add(agent_error)
    await db_session.commit()
    await db_session.refresh(agent_error)
    assert agent_error.id is not None
    assert agent_error.agent_id == agent.id
    assert agent_error.severity == Severity.minor


@pytest.mark.asyncio
async def test_agent_error_enum_enforcement(
    agent_error_factory: AgentErrorFactory,
    agent_factory: AgentFactory,
    task_factory: TaskFactory,
    db_session: AsyncSession,
) -> None:
    from tests.factories.attack_factory import AttackFactory
    from tests.factories.user_factory import UserFactory

    user = UserFactory.build()
    db_session.add(user)
    await db_session.commit()
    from tests.factories.operating_system_factory import OperatingSystemFactory

    os = OperatingSystemFactory.build()
    db_session.add(os)
    await db_session.commit()
    agent = agent_factory.build(operating_system_id=os.id, user_id=user.id)
    db_session.add(agent)
    await db_session.commit()
    attack = AttackFactory.build()
    db_session.add(attack)
    await db_session.commit()
    task = task_factory.build(attack_id=attack.id)
    db_session.add(task)
    await db_session.commit()
    agent_error = agent_error_factory.build(
        agent_id=agent.id, task_id=task.id, severity="notaseverity"
    )
    db_session.add(agent_error)
    with pytest.raises(sqlalchemy.exc.StatementError):
        await db_session.commit()


@pytest.mark.asyncio
async def test_agent_error_relationships(
    agent_factory: AgentFactory,
    task_factory: TaskFactory,
    agent_error_factory: AgentErrorFactory,
    db_session: AsyncSession,
) -> None:
    from tests.factories.attack_factory import AttackFactory
    from tests.factories.user_factory import UserFactory

    user = UserFactory.build()
    db_session.add(user)
    await db_session.commit()
    from tests.factories.operating_system_factory import OperatingSystemFactory

    os = OperatingSystemFactory.build()
    db_session.add(os)
    await db_session.commit()
    agent = agent_factory.build(operating_system_id=os.id, user_id=user.id)
    db_session.add(agent)
    await db_session.commit()
    attack = AttackFactory.build()
    db_session.add(attack)
    await db_session.commit()
    task = task_factory.build(attack_id=attack.id)
    db_session.add(task)
    await db_session.commit()
    error = agent_error_factory.build(
        agent_id=agent.id,
        task_id=task.id,
        severity=Severity.critical,
        details={"foo": "bar"},
        error_code="E1234",
    )
    db_session.add(error)
    await db_session.commit()
    await db_session.refresh(error)
    assert error.task_id == task.id
    assert error.details == {"foo": "bar"}
    assert error.error_code == "E1234"
    assert error.agent.id == agent.id


@pytest.mark.asyncio
async def test_agent_error_required_fields(
    agent_error_factory: AgentErrorFactory,
    db_session: AsyncSession,
) -> None:
    agent_error = AgentError()
    db_session.add(agent_error)
    with pytest.raises(sqlalchemy.exc.StatementError):
        await db_session.commit()
