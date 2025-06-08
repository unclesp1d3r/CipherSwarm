"""
Unit tests for hash list service.
"""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.hash_list_service import (
    HashListNotFoundError,
    create_hash_list_service,
    get_hash_list_service,
    list_hash_lists_service,
)
from app.schemas.hash_list import HashListCreate
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.user_factory import UserFactory
from tests.utils.hash_type_utils import get_or_create_hash_type


@pytest.mark.asyncio
async def test_create_hash_list_service_success(db_session: AsyncSession) -> None:
    """Test successful hash list creation."""
    # Set factory sessions
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    UserFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]

    # Create test data
    project = await ProjectFactory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")
    user = await UserFactory.create_async()

    # Create hash list data
    data = HashListCreate(
        name="Test Hash List",
        description="A test hash list",
        project_id=project.id,
        hash_type_id=hash_type.id,
        is_unavailable=False,
    )

    # Create hash list
    result = await create_hash_list_service(data, db_session, user)

    assert result.name == "Test Hash List"
    assert result.description == "A test hash list"
    assert result.project_id == project.id
    assert result.hash_type_id == hash_type.id
    assert result.is_unavailable is False


@pytest.mark.asyncio
async def test_get_hash_list_service_success(db_session: AsyncSession) -> None:
    """Test successful hash list retrieval."""
    # Set factory sessions
    HashListFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]

    # Create test data
    project = await ProjectFactory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Create test hash list
    hash_list = await HashListFactory.create_async(
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    # Get hash list
    result = await get_hash_list_service(hash_list.id, db_session)

    assert result.id == hash_list.id
    assert result.name == hash_list.name
    assert result.project_id == project.id


@pytest.mark.asyncio
async def test_get_hash_list_service_not_found(db_session: AsyncSession) -> None:
    """Test hash list retrieval with non-existent ID."""
    with pytest.raises(HashListNotFoundError):
        await get_hash_list_service(999999, db_session)


@pytest.mark.asyncio
async def test_list_hash_lists_service_success(db_session: AsyncSession) -> None:
    """Test successful hash list listing."""
    # Set factory sessions
    HashListFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]

    # Create test data
    project = await ProjectFactory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Create test hash lists
    await HashListFactory.create_async(
        name="Hash List 1",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )
    await HashListFactory.create_async(
        name="Hash List 2",
        project_id=project.id,
        hash_type_id=hash_type.id,
    )

    # List hash lists
    result, total = await list_hash_lists_service(db_session, project_id=project.id)

    assert len(result) == 2
    assert total == 2


@pytest.mark.asyncio
async def test_list_hash_lists_service_with_pagination(
    db_session: AsyncSession,
) -> None:
    """Test hash list listing with pagination."""
    # Set factory sessions
    HashListFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]
    ProjectFactory.__async_session__ = db_session  # type: ignore[assignment, unused-ignore]

    # Create test data
    project = await ProjectFactory.create_async()
    hash_type = await get_or_create_hash_type(db_session, 100, "sha256")

    # Create test hash lists
    for i in range(5):
        await HashListFactory.create_async(
            name=f"Hash List {i}",
            project_id=project.id,
            hash_type_id=hash_type.id,
        )

    # List hash lists with pagination
    result, total = await list_hash_lists_service(
        db_session, project_id=project.id, skip=0, limit=2
    )

    assert len(result) == 2
    assert total == 5
