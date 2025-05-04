import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.attack import AttackMode, AttackState
from tests.factories.attack_factory import AttackFactory


@pytest.mark.asyncio
async def test_create_attack_minimal(
    attack_factory: AttackFactory, db_session: AsyncSession
) -> None:
    attack = attack_factory.build()
    attack.hash_type_id = 0
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    assert attack.id is not None
    assert attack.name.startswith("Attack")
    assert attack.state == AttackState.PENDING
    assert attack.hash_type_id == 0


@pytest.mark.asyncio
async def test_attack_enum_enforcement(
    attack_factory: AttackFactory, db_session: AsyncSession
) -> None:
    attack = attack_factory.build(state="notastate")
    db_session.add(attack)
    with pytest.raises(sqlalchemy.exc.StatementError):
        await db_session.commit()
    await db_session.rollback()
    attack = attack_factory.build(hash_type_id="notahash")
    db_session.add(attack)
    with pytest.raises(sqlalchemy.exc.StatementError):
        await db_session.commit()
    await db_session.rollback()
    attack = attack_factory.build(attack_mode="notamode")
    db_session.add(attack)
    with pytest.raises(sqlalchemy.exc.StatementError):
        await db_session.commit()


@pytest.mark.asyncio
async def test_attack_update_and_delete(
    attack_factory: AttackFactory, db_session: AsyncSession
) -> None:
    attack = attack_factory.build(
        state=AttackState.PENDING, hash_type_id=100, attack_mode=AttackMode.MASK
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    attack.description = "Updated description"
    await db_session.commit()
    await db_session.refresh(attack)
    assert attack.description == "Updated description"
    await db_session.delete(attack)
    await db_session.commit()
    result = await db_session.get(attack.__class__, attack.id)
    assert result is None
