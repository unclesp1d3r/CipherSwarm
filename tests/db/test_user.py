# pyright: reportCallIssue=false

import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_create_user_minimal(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    assert user.id is not None
    assert user.email.startswith("user")
    assert user.role.name == "analyst"
    assert user.is_active
    assert user.is_verified


@pytest.mark.asyncio
async def test_user_enum_validation(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    user = user_factory.build(role="notarole")
    db_session.add(user)
    with pytest.raises(sqlalchemy.exc.StatementError):
        await db_session.commit()


@pytest.mark.asyncio
async def test_user_update_and_delete(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    user = user_factory.build()
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    user.name = "Updated Name"
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    assert user.name == "Updated Name"
    await db_session.delete(user)
    await db_session.commit()
    result = await db_session.get(user.__class__, user.id)
    assert result is None
