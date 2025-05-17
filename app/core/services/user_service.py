from collections.abc import Callable

from pydantic import BaseModel
from sqlalchemy import func, or_, select
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import verify_password
from app.models.project import Project, ProjectUserAssociation
from app.models.user import User
from app.schemas.user import UserListItem, UserRead


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


async def get_user_project_context_service(
    user: User, db: AsyncSession, active_project_id: int | None = None
) -> dict[str, object]:
    # Get all projects the user has access to
    result = await db.execute(
        select(Project)
        .join(ProjectUserAssociation)
        .where(ProjectUserAssociation.user_id == user.id)
    )
    projects = result.scalars().all()
    available_projects = [{"id": p.id, "name": p.name} for p in projects]
    # Get active project (by id from cookie)
    active_project = None
    if active_project_id:
        active = next((p for p in projects if p.id == active_project_id), None)
        if active:
            active_project = {"id": active.id, "name": active.name}
    # User info (minimal)
    user_info = {"id": str(user.id), "email": user.email, "role": user.role.value}
    return {
        "user": user_info,
        "active_project": active_project,
        "available_projects": available_projects,
    }


async def set_user_project_context_service(
    user: User, project_id: int, db: AsyncSession
) -> None:
    # Validate user has access to the project
    result = await db.execute(
        select(ProjectUserAssociation).where(
            ProjectUserAssociation.user_id == user.id,
            ProjectUserAssociation.project_id == project_id,
        )
    )
    assoc = result.scalar_one_or_none()
    if not assoc:
        raise NoResultFound("User does not have access to this project.")
    # No DB mutation; context is session/cookie-based


async def change_user_password_service(
    user: User,
    db: AsyncSession,
    *,
    old_password: str,
    new_password: str,
    password_hasher: Callable[[str], str],
    password_verifier: Callable[[str, str], bool],
) -> User:
    if not password_verifier(old_password, user.hashed_password):
        raise ValueError("Current password is incorrect.")
    user.hashed_password = password_hasher(new_password)
    await db.commit()
    await db.refresh(user)
    return user


class PaginatedUserList(BaseModel):
    users: list[UserRead]
    total: int


async def list_users_paginated_service(
    db: AsyncSession,
    page: int = 1,
    page_size: int = 20,
    search: str | None = None,
) -> PaginatedUserList:
    query = select(User)
    if search:
        like = f"%{search.lower()}%"
        query = query.where(
            or_(
                func.lower(User.name).like(like),
                func.lower(User.email).like(like),
            )
        )
    total = await db.scalar(select(func.count()).select_from(query.subquery()))
    if total is None:
        total = 0
    query = query.order_by(User.name).offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(query)
    users = result.scalars().all()
    return PaginatedUserList(
        users=[
            UserRead.model_validate({**u.__dict__, "role": u.role.value}) for u in users
        ],
        total=total,
    )


__all__ = [
    "authenticate_user_service",
    "change_user_password_service",
    "get_user_project_context_service",
    "list_users_paginated_service",
    "list_users_service",
    "set_user_project_context_service",
    "update_user_profile_service",
]
