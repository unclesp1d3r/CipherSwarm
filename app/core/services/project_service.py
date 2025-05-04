from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.project import Project
from app.schemas.project import ProjectCreate, ProjectRead, ProjectUpdate


class ProjectNotFoundError(Exception):
    pass


async def list_projects_service(db: AsyncSession) -> list[ProjectRead]:
    result = await db.execute(select(Project))
    projects = result.scalars().all()
    return [ProjectRead.model_validate(p) for p in projects]


async def get_project_service(project_id: UUID, db: AsyncSession) -> ProjectRead:
    result = await db.execute(select(Project).where(Project.id == project_id))
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
    return ProjectRead.model_validate(project)


async def update_project_service(
    project_id: UUID, data: ProjectUpdate, db: AsyncSession
) -> ProjectRead:
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise ProjectNotFoundError(f"Project {project_id} not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(project, field, value)
    await db.commit()
    await db.refresh(project)
    return ProjectRead.model_validate(project)


async def delete_project_service(project_id: UUID, db: AsyncSession) -> None:
    result = await db.execute(select(Project).where(Project.id == project_id))
    project = result.scalar_one_or_none()
    if not project:
        raise ProjectNotFoundError(f"Project {project_id} not found")
    await db.delete(project)
    await db.commit()
