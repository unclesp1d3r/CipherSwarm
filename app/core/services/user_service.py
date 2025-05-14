from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.schemas.user import UserListItem


async def list_users_service(db: AsyncSession) -> list[UserListItem]:
    result = await db.execute(select(User))
    users = result.scalars().all()
    return [
        UserListItem(username=u.name, email=u.email, is_active=u.is_active)
        for u in users
    ]


__all__ = ["list_users_service"]
