"""Base model module with common fields for all database models."""

from collections.abc import AsyncGenerator

from fastapi_users_db_sqlalchemy import SQLAlchemyUserDatabase
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.base import Base  # noqa: F401
from app.models.user import User


async def get_user_db(
    session: AsyncSession,
) -> AsyncGenerator[SQLAlchemyUserDatabase[User, int]]:
    yield SQLAlchemyUserDatabase(session, User)
