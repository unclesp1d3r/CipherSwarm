# pyright: reportGeneralTypeIssues=false
import pytest
from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.task import Task, TaskStatus
from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.task_factory import TaskFactory


@pytest.fixture(autouse=True)
def set_async_sessions(db_session: AsyncSession) -> None:
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    CampaignFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    AttackFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    TaskFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    HashListFactory.__async_session__ = db_session


@pytest.mark.asyncio
async def test_create_task_minimal(
    db_session: AsyncSession,
) -> None:
    project = await ProjectFactory.create_async()
    hash_list = await HashListFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await AttackFactory.create_async(campaign_id=campaign.id)
    task = await TaskFactory.create_async(attack_id=attack.id)
    assert task.id is not None
    assert task.status == TaskStatus.PENDING


@pytest.mark.asyncio
async def test_task_enum_enforcement(
    db_session: AsyncSession,
) -> None:
    project = await ProjectFactory.create_async()
    hash_list = await HashListFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await AttackFactory.create_async(campaign_id=campaign.id)
    with pytest.raises(Exception):  # noqa: B017
        await TaskFactory.create_async(attack_id=attack.id, status="notastatus")


@pytest.mark.asyncio
async def test_task_update_and_delete(
    db_session: AsyncSession,
) -> None:
    project = await ProjectFactory.create_async()
    hash_list = await HashListFactory.create_async(project_id=project.id)
    campaign = await CampaignFactory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await AttackFactory.create_async(campaign_id=campaign.id)
    task = await TaskFactory.create_async(attack_id=attack.id)
    await db_session.execute(
        update(Task).where(Task.id == task.id).values(status=TaskStatus.COMPLETED)
    )
    await db_session.commit()
    # Re-query the task to ensure it is managed by the session
    task = await db_session.get(task.__class__, task.id)
    assert task is not None
    assert task.status == TaskStatus.COMPLETED
    await db_session.delete(task)
    await db_session.commit()
    result = await db_session.get(task.__class__, task.id)
    assert result is None
