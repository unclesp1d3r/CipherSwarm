from sqlalchemy import select
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.auth import verify_password
from app.models.project import Project, ProjectUserAssociation
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


__all__ = [
    "authenticate_user_service",
    "get_user_project_context_service",
    "list_users_service",
    "set_user_project_context_service",
    "update_user_profile_service",
]
