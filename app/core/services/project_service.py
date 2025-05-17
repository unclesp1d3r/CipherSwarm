from datetime import UTC, datetime

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.project import Project, ProjectUserAssociation
from app.schemas.project import ProjectCreate, ProjectRead, ProjectUpdate


class ProjectNotFoundError(Exception):
    pass


async def list_projects_service(
    db: AsyncSession,
    search: str | None = None,
    page: int = 1,
    page_size: int = 20,
) -> tuple[list[ProjectRead], int]:
    stmt = (
        select(Project)
        .options(selectinload(Project.user_associations))
        .where(Project.archived_at.is_(None))
    )
    if search:
        stmt = stmt.where(
            or_(
                Project.name.ilike(f"%{search}%"),
                Project.description.ilike(f"%{search}%"),
            )
        )
    total = (
        await db.execute(select(func.count()).select_from(stmt.subquery()))
    ).scalar_one()
    stmt = stmt.order_by(Project.created_at.desc())
    offset = (page - 1) * page_size
    stmt = stmt.offset(offset).limit(page_size)
    result = await db.execute(stmt)
    projects = result.scalars().all()
    return [ProjectRead.model_validate(p) for p in projects], total


async def get_project_service(project_id: int, db: AsyncSession) -> ProjectRead:
    result = await db.execute(
        select(Project).where(Project.id == project_id, Project.archived_at.is_(None))
    )
    project = result.scalar_one_or_none()
    if not project:
        raise ProjectNotFoundError(f"Project {project_id} not found")
    return ProjectRead.model_validate(project)


async def create_project_service(data: ProjectCreate, db: AsyncSession) -> ProjectRead:
    project = Project(
        name=data.name,
        description=data.description,
        private=data.private,
        archived_at=data.archived_at,
        notes=data.notes,
    )
    db.add(project)
    await db.commit()
    await db.refresh(project)
    # Eagerly load user_associations and users for serialization
    result = await db.execute(
        select(Project)
        .options(
            selectinload(Project.user_associations).selectinload(
                ProjectUserAssociation.user
            )
        )
        .where(Project.id == project.id)
    )
    project_with_users = result.scalar_one()
    return ProjectRead.model_validate(project_with_users)


async def update_project_service(
    project_id: int, data: ProjectUpdate, db: AsyncSession
) -> ProjectRead:
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise ProjectNotFoundError(f"Project {project_id} not found")
    update_dict = data.model_dump(exclude_unset=True)
    users = update_dict.pop("users", None)
    for field, value in update_dict.items():
        setattr(project, field, value)
    if users is not None:
        # Remove all existing associations
        project.user_associations.clear()
        if users:
            # Add new associations (default role: member)
            for user_id in users:
                assoc = ProjectUserAssociation(user_id=user_id, project_id=project.id)
                project.user_associations.append(assoc)
    await db.commit()
    await db.refresh(project)
    # Eagerly load user_associations and users for serialization
    result = await db.execute(
        select(Project)
        .options(
            selectinload(Project.user_associations).selectinload(
                ProjectUserAssociation.user
            )
        )
        .where(Project.id == project.id)
    )
    project_with_users = result.scalar_one()
    # Extract user UUIDs for ProjectRead
    user_ids = [assoc.user_id for assoc in project_with_users.user_associations]
    # Build dict for ProjectRead
    project_dict = {**project_with_users.__dict__, "users": user_ids}
    return ProjectRead.model_validate(project_dict)


async def delete_project_service(project_id: int, db: AsyncSession) -> None:
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise ProjectNotFoundError(f"Project {project_id} not found")
    project.archived_at = datetime.now(UTC)
    await db.commit()
