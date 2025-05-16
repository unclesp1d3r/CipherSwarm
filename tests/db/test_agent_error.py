# pyright: reportGeneralTypeIssues=false

import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent import AgentState, AgentType, OperatingSystemEnum
from app.models.agent_error import Severity
from tests.factories.agent_error_factory import AgentErrorFactory
from tests.factories.agent_factory import AgentFactory
from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.task_factory import TaskFactory


@pytest.fixture(autouse=True)
def set_async_sessions(db_session: AsyncSession) -> None:
    AgentFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    AgentErrorFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    TaskFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    CampaignFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    AttackFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    HashListFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]


@pytest.mark.asyncio
async def test_create_agent_error_minimal(
    agent_error_factory: AgentErrorFactory,
    db_session: AsyncSession,
) -> None:
    agent = await AgentFactory.create_async(
        host_name="err-agent",
        client_signature="sig",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token="csa_1_testtoken",
        operating_system=OperatingSystemEnum.linux,
    )
    agent_error = await agent_error_factory.create_async(agent_id=agent.id)
    assert agent_error.id is not None
    assert agent_error.severity == Severity.minor


@pytest.mark.asyncio
async def test_agent_error_enum_enforcement(
    agent_error_factory: AgentErrorFactory,
    db_session: AsyncSession,
) -> None:
    agent = await AgentFactory.create_async(
        host_name="enum-agent",
        client_signature="sig",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token="csa_2_testtoken",
        operating_system=OperatingSystemEnum.linux,
    )
    with pytest.raises(Exception):  # noqa: B017
        await agent_error_factory.create_async(
            agent_id=agent.id, severity="notaseverity"
        )


@pytest.mark.asyncio
async def test_agent_error_required_fields(
    agent_error_factory: AgentErrorFactory,
    db_session: AsyncSession,
) -> None:
    from app.models.agent_error import AgentError

    agent_error = AgentError()
    db_session.add(agent_error)
    with pytest.raises(sqlalchemy.exc.StatementError):
        await db_session.commit()
