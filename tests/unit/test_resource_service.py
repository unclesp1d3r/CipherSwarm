import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.resource_service import list_resources_service
from app.schemas.resource import ResourceListResponse
from tests.factories.attack_resource_file_factory import AttackResourceFileFactory


@pytest.mark.asyncio
async def test_resource_list_response_includes_total_pages(
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    """Test that ResourceListResponse includes total_pages field."""

    # Create some test resources
    await attack_resource_file_factory.create_async()
    await attack_resource_file_factory.create_async()
    await attack_resource_file_factory.create_async()

    # Test with page_size=2 (should have 2 pages)
    response = await list_resources_service(
        db=db_session,
        page=1,
        page_size=2,
    )

    assert isinstance(response, ResourceListResponse)
    assert response.total == 3
    assert response.page == 1
    assert response.page_size == 2
    assert response.total_pages == 2  # ceil(3/2) = 2

    # Test with page_size=3 (should have 1 page)
    response = await list_resources_service(
        db=db_session,
        page=1,
        page_size=3,
    )

    assert response.total_pages == 1  # ceil(3/3) = 1

    # Test with page_size=5 (should have 1 page)
    response = await list_resources_service(
        db=db_session,
        page=1,
        page_size=5,
    )

    assert response.total_pages == 1  # ceil(3/5) = 1


@pytest.mark.asyncio
async def test_resource_list_response_handles_empty_results(
    db_session: AsyncSession,
) -> None:
    """Test that ResourceListResponse handles empty results correctly."""

    response = await list_resources_service(
        db=db_session,
        page=1,
        page_size=10,
    )

    assert isinstance(response, ResourceListResponse)
    assert response.total == 0
    assert response.page == 1
    assert response.page_size == 10
    assert response.total_pages == 0  # ceil(0/10) = 0
    assert response.items == []


@pytest.mark.asyncio
async def test_resource_list_response_handles_page_size_zero(
    db_session: AsyncSession,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    """Test that ResourceListResponse handles page_size=0 safely."""

    # Create a test resource
    await attack_resource_file_factory.create_async()

    response = await list_resources_service(
        db=db_session,
        page=1,
        page_size=0,
    )

    assert isinstance(response, ResourceListResponse)
    assert response.total == 1
    assert response.page == 1
    assert response.page_size == 0
    assert response.total_pages == 0  # Safe handling for page_size=0
