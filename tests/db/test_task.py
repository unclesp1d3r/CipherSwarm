import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.task import TaskStatus
from tests.factories.attack_factory import AttackFactory
from tests.factories.task_factory import TaskFactory


@pytest.mark.asyncio
async def test_create_task_minimal(
    task_factory: TaskFactory, attack_factory: AttackFactory, db_session: AsyncSession
) -> None:
    attack = attack_factory.build()
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = task_factory.build(attack_id=attack.id)
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    assert task.id is not None
    assert task.attack_id == attack.id
    assert task.status == TaskStatus.PENDING


@pytest.mark.asyncio
async def test_task_enum_enforcement(
    task_factory: TaskFactory, attack_factory: AttackFactory, db_session: AsyncSession
) -> None:
    attack = attack_factory.build()
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = task_factory.build(attack_id=attack.id, status="notastatus")
    db_session.add(task)
    with pytest.raises(sqlalchemy.exc.StatementError):
        await db_session.commit()


@pytest.mark.asyncio
async def test_task_update_and_delete(
    task_factory: TaskFactory, attack_factory: AttackFactory, db_session: AsyncSession
) -> None:
    attack = attack_factory.build()
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = task_factory.build(attack_id=attack.id)
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.status = TaskStatus.COMPLETED
    await db_session.commit()
    await db_session.refresh(task)
    assert task.status == TaskStatus.COMPLETED
    await db_session.delete(task)
    await db_session.commit()
    result = await db_session.get(task.__class__, task.id)
    assert result is None
