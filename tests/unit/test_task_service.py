"""
Unit tests for task service.
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.task_service import (
    assign_task_service,
    get_task_by_id_service,
    accept_task_service,
    exhaust_task_service,
    abandon_task_service,
    get_task_zaps_service,
    NoPendingTasksError,
    TaskNotFoundError,
    TaskAlreadyCompletedError,
    TaskAlreadyExhaustedError,
    TaskAlreadyAbandonedError,
)
from app.core.exceptions import InvalidAgentTokenError
from app.models.task import Task, TaskStatus
from tests.factories.agent_factory import AgentFactory
from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.task_factory import TaskFactory


@pytest.mark.asyncio
async def test_assign_task_service_success(db_session: AsyncSession) -> None:
    """Test successful task assignment to agent."""
    # Set factory sessions
    ProjectFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    AttackFactory.__async_session__ = db_session
    TaskFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(campaign_id=campaign.id)

    # Create a pending task
    task = await TaskFactory.create_async(
        attack_id=attack.id,
        status=TaskStatus.PENDING,
        agent_id=None,
    )

    # Assign task
    result = await assign_task_service(
        db_session,
        f"Bearer {agent.token}",
        "test-user-agent",
    )

    assert result.id == task.id

    # Verify task was assigned to agent
    await db_session.refresh(task)
    assert task.agent_id == agent.id


@pytest.mark.asyncio
async def test_assign_task_service_invalid_token(db_session: AsyncSession) -> None:
    """Test task assignment with invalid agent token."""
    with pytest.raises(InvalidAgentTokenError):
        await assign_task_service(
            db_session,
            "Bearer invalid_token",
            "test-user-agent",
        )


@pytest.mark.asyncio
async def test_assign_task_service_no_pending_tasks(db_session: AsyncSession) -> None:
    """Test task assignment when no pending tasks are available."""
    # Set factory sessions
    ProjectFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(project_id=project.id)

    # Try to assign task when none are available
    with pytest.raises(NoPendingTasksError):
        await assign_task_service(
            db_session,
            f"Bearer {agent.token}",
            "test-user-agent",
        )


@pytest.mark.asyncio
async def test_get_task_by_id_service_success(db_session: AsyncSession) -> None:
    """Test successful task retrieval."""
    # Set factory sessions
    TaskFactory.__async_session__ = db_session
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(campaign_id=campaign.id)
    task = await TaskFactory.create_async(attack_id=attack.id)

    # Get task
    result = await get_task_by_id_service(task.id, db_session, agent)

    assert result.id == task.id
    assert result.attack_id == attack.id


@pytest.mark.asyncio
async def test_get_task_by_id_service_not_found(db_session: AsyncSession) -> None:
    """Test task retrieval with non-existent ID."""
    # Set factory sessions
    ProjectFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(project_id=project.id)

    with pytest.raises(TaskNotFoundError):
        await get_task_by_id_service(999999, db_session, agent)


@pytest.mark.asyncio
async def test_accept_task_service_success(db_session: AsyncSession) -> None:
    """Test successful task acceptance."""
    # Set factory sessions
    TaskFactory.__async_session__ = db_session
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(campaign_id=campaign.id)
    task = await TaskFactory.create_async(
        attack_id=attack.id,
        agent_id=agent.id,
        status=TaskStatus.ASSIGNED,
    )

    # Accept task
    result = await accept_task_service(task.id, db_session, agent)

    assert result.id == task.id

    # Verify task status was updated
    await db_session.refresh(task)
    assert task.status == TaskStatus.RUNNING


@pytest.mark.asyncio
async def test_exhaust_task_service_success(db_session: AsyncSession) -> None:
    """Test successful task exhaustion."""
    # Set factory sessions
    TaskFactory.__async_session__ = db_session
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(campaign_id=campaign.id)
    task = await TaskFactory.create_async(
        attack_id=attack.id,
        agent_id=agent.id,
        status=TaskStatus.RUNNING,
    )

    # Exhaust task
    result = await exhaust_task_service(task.id, db_session, agent)

    assert result.id == task.id

    # Verify task status was updated
    await db_session.refresh(task)
    assert task.status == TaskStatus.EXHAUSTED


@pytest.mark.asyncio
async def test_exhaust_task_service_already_exhausted(
    db_session: AsyncSession,
) -> None:
    """Test task exhaustion when task is already exhausted."""
    # Set factory sessions
    TaskFactory.__async_session__ = db_session
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(campaign_id=campaign.id)
    task = await TaskFactory.create_async(
        attack_id=attack.id,
        agent_id=agent.id,
        status=TaskStatus.EXHAUSTED,
    )

    # Try to exhaust already exhausted task
    with pytest.raises(TaskAlreadyExhaustedError):
        await exhaust_task_service(task.id, db_session, agent)


@pytest.mark.asyncio
async def test_abandon_task_service_success(db_session: AsyncSession) -> None:
    """Test successful task abandonment."""
    # Set factory sessions
    TaskFactory.__async_session__ = db_session
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(campaign_id=campaign.id)
    task = await TaskFactory.create_async(
        attack_id=attack.id,
        agent_id=agent.id,
        status=TaskStatus.RUNNING,
    )

    # Abandon task
    result = await abandon_task_service(task.id, db_session, agent)

    assert result.id == task.id

    # Verify task status was updated
    await db_session.refresh(task)
    assert task.status == TaskStatus.ABANDONED


@pytest.mark.asyncio
async def test_abandon_task_service_already_abandoned(
    db_session: AsyncSession,
) -> None:
    """Test task abandonment when task is already abandoned."""
    # Set factory sessions
    TaskFactory.__async_session__ = db_session
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(campaign_id=campaign.id)
    task = await TaskFactory.create_async(
        attack_id=attack.id,
        agent_id=agent.id,
        status=TaskStatus.ABANDONED,
    )

    # Try to abandon already abandoned task
    with pytest.raises(TaskAlreadyAbandonedError):
        await abandon_task_service(task.id, db_session, agent)


@pytest.mark.asyncio
async def test_get_task_zaps_service_success(db_session: AsyncSession) -> None:
    """Test successful task zaps retrieval."""
    # Set factory sessions
    TaskFactory.__async_session__ = db_session
    AttackFactory.__async_session__ = db_session
    CampaignFactory.__async_session__ = db_session
    ProjectFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(project_id=project.id)
    attack = await AttackFactory.create_async(campaign_id=campaign.id)
    task = await TaskFactory.create_async(
        attack_id=attack.id,
        agent_id=agent.id,
    )

    # Get task zaps
    result = await get_task_zaps_service(task.id, db_session, agent)

    assert isinstance(result, list)
    # Should return empty list if no zaps exist
    assert len(result) == 0


@pytest.mark.asyncio
async def test_get_task_zaps_service_not_found(db_session: AsyncSession) -> None:
    """Test task zaps retrieval with non-existent task ID."""
    # Set factory sessions
    ProjectFactory.__async_session__ = db_session
    AgentFactory.__async_session__ = db_session

    # Create test data
    project = await ProjectFactory.create_async()
    agent = await AgentFactory.create_async(project_id=project.id)

    with pytest.raises(TaskNotFoundError):
        await get_task_zaps_service(999999, db_session, agent)
