import pytest
import sqlalchemy.exc
from sqlalchemy.ext.asyncio import AsyncSession

from tests.factories.project_factory import ProjectFactory


@pytest.mark.asyncio
async def test_create_project_minimal(
    project_factory: ProjectFactory, db_session: AsyncSession
) -> None:
    ProjectFactory.__async_session__ = db_session
    project = await project_factory.create_async(name="UniqueProj")
    assert project.id is not None
    assert project.name == "UniqueProj"
    assert project.private is False


@pytest.mark.asyncio
async def test_project_unique_name_constraint(
    project_factory: ProjectFactory, db_session: AsyncSession
) -> None:
    ProjectFactory.__async_session__ = db_session
    await project_factory.create_async(name="UniqueProj2")
    with pytest.raises(sqlalchemy.exc.IntegrityError):
        # Should fail due to unique constraint
        await project_factory.create_async(name="UniqueProj2")


@pytest.mark.asyncio
async def test_project_update_and_delete(
    project_factory: ProjectFactory, db_session: AsyncSession
) -> None:
    ProjectFactory.__async_session__ = db_session
    project = await project_factory.create_async(
        name="Update Project", description="Initial description"
    )
    project.description = "Updated description"
    await db_session.commit()
    assert project.description == "Updated description"
    await db_session.delete(project)
    await db_session.commit()
    result = await db_session.get(project.__class__, project.id)
    assert result is None
