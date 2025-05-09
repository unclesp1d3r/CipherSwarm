# pyright: reportCallIssue=false

import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import UserRole
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_create_user_minimal(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    UserFactory.__async_session__ = db_session
    user = await user_factory.create_async()
    assert user.id is not None
    assert user.email is not None
    assert user.role == UserRole.ANALYST
    assert user.is_active
    assert user.is_verified


@pytest.mark.asyncio
async def test_user_enum_validation(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    UserFactory.__async_session__ = db_session
    with pytest.raises(sqlalchemy.exc.StatementError):  # noqa: PT012
        await user_factory.create_async(role="notarole")
        await db_session.commit()


@pytest.mark.asyncio
async def test_user_update_and_delete(
    user_factory: UserFactory, db_session: AsyncSession
) -> None:
    UserFactory.__async_session__ = db_session
    user = await user_factory.create_async()
    user.name = "Updated Name"
    await db_session.commit()
    assert user.name == "Updated Name"
    await db_session.delete(user)
    await db_session.commit()
    result = await db_session.get(user.__class__, user.id)
    assert result is None
