from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import verify_password
from app.models.user import User
from app.schemas.user import UserListItem


async def list_users_service(db: AsyncSession) -> list[UserListItem]:
    result = await db.execute(select(User))
    users = result.scalars().all()
    return [
        UserListItem(username=u.name, email=u.email, is_active=u.is_active)
        for u in users
    ]


async def authenticate_user_service(
    email: str, password: str, db: AsyncSession
) -> User | None:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(password, user.hashed_password):
        return None
    return user


async def update_user_profile_service(
    user: User, db: AsyncSession, *, name: str | None = None, email: str | None = None
) -> User:
    updated = False
    if name is not None and name != user.name:
        user.name = name
        updated = True
    if email is not None and email != user.email:
        user.email = email
        updated = True
    if updated:
        await db.commit()
        await db.refresh(user)
    return user


__all__ = [
    "authenticate_user_service",
    "list_users_service",
    "update_user_profile_service",
]
