import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.project import Project
from tests.factories.project_factory import ProjectFactory


@pytest.mark.asyncio
async def test_create_project_minimal(
    project_factory: ProjectFactory, db_session: AsyncSession
) -> None:
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    assert project.id is not None
    assert project.name.startswith("Project")
    assert project.private is False


@pytest.mark.asyncio
async def test_project_unique_name_constraint(
    project_factory: ProjectFactory, db_session: AsyncSession
) -> None:
    project1 = project_factory.build(name="Unique Project")
    db_session.add(project1)
    await db_session.commit()
    await db_session.refresh(project1)
    project2 = project_factory.build(name="Unique Project", private=True)
    db_session.add(project2)
    with pytest.raises(sqlalchemy.exc.IntegrityError):
        await db_session.commit()
    await db_session.rollback()


@pytest.mark.asyncio
async def test_project_update_and_delete(
    project_factory: ProjectFactory, db_session: AsyncSession
) -> None:
    project = project_factory.build(
        name="Update Project", description="Initial description"
    )
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    project.description = "Updated description"
    await db_session.commit()
    await db_session.refresh(project)
    assert project.description == "Updated description"
    await db_session.delete(project)
    await db_session.commit()
    result = await db_session.get(Project, project.id)
    assert result is None
