"""
Unit tests for project service.
"""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.project_service import (
    list_projects_service,
    list_projects_service_offset,
)
from tests.factories.project_factory import ProjectFactory
from tests.factories.user_factory import UserFactory


@pytest.mark.asyncio
async def test_list_projects_service_offset_pagination(
    db_session: AsyncSession,
    project_factory: ProjectFactory,
    user_factory: UserFactory,
) -> None:
    """Test that offset-based pagination works correctly."""

    # Create test projects
    projects = []
    for i in range(5):
        project = await project_factory.create_async(name=f"Project {i:02d}")
        projects.append(project)

    # Test offset-based pagination
    result, total = await list_projects_service_offset(db=db_session, skip=0, limit=2)
    assert len(result) == 2
    assert total == 5

    # Test second page
    result, total = await list_projects_service_offset(db=db_session, skip=2, limit=2)
    assert len(result) == 2
    assert total == 5

    # Test last page
    result, total = await list_projects_service_offset(db=db_session, skip=4, limit=2)
    assert len(result) == 1
    assert total == 5


@pytest.mark.asyncio
async def test_list_projects_service_compatibility(
    db_session: AsyncSession,
    project_factory: ProjectFactory,
) -> None:
    """Test that page-based and offset-based services return equivalent results."""

    # Create test projects
    for i in range(10):
        await project_factory.create_async(name=f"Project {i:02d}")

    # Test page 1 (items 0-4) vs offset 0, limit 5
    page_result, page_total = await list_projects_service(
        db=db_session, page=1, page_size=5
    )
    offset_result, offset_total = await list_projects_service_offset(
        db=db_session, skip=0, limit=5
    )

    assert len(page_result) == len(offset_result) == 5
    assert page_total == offset_total == 10

    # Compare project IDs to ensure same ordering
    page_ids = [p.id for p in page_result]
    offset_ids = [p.id for p in offset_result]
    assert page_ids == offset_ids

    # Test page 2 (items 5-9) vs offset 5, limit 5
    page_result, page_total = await list_projects_service(
        db=db_session, page=2, page_size=5
    )
    offset_result, offset_total = await list_projects_service_offset(
        db=db_session, skip=5, limit=5
    )

    assert len(page_result) == len(offset_result) == 5
    assert page_total == offset_total == 10

    # Compare project IDs to ensure same ordering
    page_ids = [p.id for p in page_result]
    offset_ids = [p.id for p in offset_result]
    assert page_ids == offset_ids


@pytest.mark.asyncio
async def test_list_projects_service_offset_with_search(
    db_session: AsyncSession,
    project_factory: ProjectFactory,
) -> None:
    """Test that offset-based pagination works with search filtering."""

    # Create test projects with unique names to avoid conflicts with other tests
    await project_factory.create_async(name="UnitTest Alpha Project")
    await project_factory.create_async(name="UnitTest Beta Project")
    await project_factory.create_async(name="UnitTest Alpha Test")
    await project_factory.create_async(name="UnitTest Gamma Project")

    # Test search with pagination
    result, total = await list_projects_service_offset(
        db=db_session, search="UnitTest Alpha", skip=0, limit=10
    )
    assert len(result) == 2
    assert total == 2
    assert all("UnitTest Alpha" in p.name for p in result)

    # Test search with pagination - first page
    result, total = await list_projects_service_offset(
        db=db_session, search="UnitTest", skip=0, limit=2
    )
    assert len(result) == 2
    assert (
        total == 4
    )  # All 4 UnitTest projects: UnitTest Alpha Project, UnitTest Beta Project, UnitTest Alpha Test, UnitTest Gamma Project

    # Test search with pagination - second page
    result, total = await list_projects_service_offset(
        db=db_session, search="UnitTest", skip=2, limit=2
    )
    assert len(result) == 2
    assert total == 4
