"""
Integration tests for Control API campaigns endpoints.

The Control API uses API key authentication and offset-based pagination.
All responses must be JSON by default, with optional MsgPack support.
Error responses must follow RFC9457 format.
"""

from http import HTTPStatus

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.project import ProjectUserAssociation, ProjectUserRole
from app.models.user import User
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory


@pytest.mark.asyncio
async def test_list_campaigns_happy_path(
    authenticated_user_client: tuple[AsyncClient, User],
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    """Test basic campaign listing with default pagination."""
    async_client, user = authenticated_user_client

    # Create project and associate user
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash list and campaigns
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    await campaign_factory.create_async(
        name="Campaign Alpha",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    await campaign_factory.create_async(
        name="Campaign Beta",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )

    # Test the endpoint
    resp = await async_client.get("/api/v1/control/campaigns")
    assert resp.status_code == HTTPStatus.OK

    data = resp.json()
    assert "items" in data
    assert "total" in data
    assert "limit" in data
    assert "offset" in data

    assert data["total"] == 2
    assert data["limit"] == 10
    assert data["offset"] == 0
    assert len(data["items"]) == 2

    # Check campaign data structure
    campaign_names = {item["name"] for item in data["items"]}
    assert campaign_names == {"Campaign Alpha", "Campaign Beta"}


@pytest.mark.asyncio
async def test_list_campaigns_pagination(
    authenticated_user_client: tuple[AsyncClient, User],
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    """Test offset-based pagination."""
    async_client, user = authenticated_user_client

    # Create project and associate user
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash list and multiple campaigns
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaigns = []
    for i in range(5):
        campaign = await campaign_factory.create_async(
            name=f"Campaign {i:02d}",
            project_id=project.id,
            hash_list_id=hash_list.id,
        )
        campaigns.append(campaign)

    # Test first page
    resp = await async_client.get("/api/v1/control/campaigns?limit=2&offset=0")
    assert resp.status_code == HTTPStatus.OK

    data = resp.json()
    assert data["total"] == 5
    assert data["limit"] == 2
    assert data["offset"] == 0
    assert len(data["items"]) == 2

    # Test second page
    resp = await async_client.get("/api/v1/control/campaigns?limit=2&offset=2")
    assert resp.status_code == HTTPStatus.OK

    data = resp.json()
    assert data["total"] == 5
    assert data["limit"] == 2
    assert data["offset"] == 2
    assert len(data["items"]) == 2

    # Test last page
    resp = await async_client.get("/api/v1/control/campaigns?limit=2&offset=4")
    assert resp.status_code == HTTPStatus.OK

    data = resp.json()
    assert data["total"] == 5
    assert data["limit"] == 2
    assert data["offset"] == 4
    assert len(data["items"]) == 1


@pytest.mark.asyncio
async def test_list_campaigns_name_filter(
    authenticated_user_client: tuple[AsyncClient, User],
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    """Test filtering campaigns by name."""
    async_client, user = authenticated_user_client

    # Create project and associate user
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash list and campaigns
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    await campaign_factory.create_async(
        name="Alpha Campaign",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    await campaign_factory.create_async(
        name="Beta Campaign",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    await campaign_factory.create_async(
        name="Alpha Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )

    # Test name filter
    resp = await async_client.get("/api/v1/control/campaigns?name=Alpha")
    assert resp.status_code == HTTPStatus.OK

    data = resp.json()
    assert data["total"] == 2
    assert len(data["items"]) == 2

    campaign_names = {item["name"] for item in data["items"]}
    assert campaign_names == {"Alpha Campaign", "Alpha Test"}


@pytest.mark.asyncio
async def test_list_campaigns_project_scoping(
    authenticated_user_client: tuple[AsyncClient, User],
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    """Test that campaigns are properly scoped to user's projects."""
    async_client, user = authenticated_user_client

    # Create two projects
    project1 = await project_factory.create_async()
    project2 = await project_factory.create_async()

    # Associate user only with project1
    assoc = ProjectUserAssociation(
        project_id=project1.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Create hash lists and campaigns in both projects
    hash_list1 = await hash_list_factory.create_async(project_id=project1.id)
    hash_list2 = await hash_list_factory.create_async(project_id=project2.id)

    await campaign_factory.create_async(
        name="Accessible Campaign",
        project_id=project1.id,
        hash_list_id=hash_list1.id,
    )
    await campaign_factory.create_async(
        name="Inaccessible Campaign",
        project_id=project2.id,
        hash_list_id=hash_list2.id,
    )

    # Test that only campaigns from accessible project are returned
    resp = await async_client.get("/api/v1/control/campaigns")
    assert resp.status_code == HTTPStatus.OK

    data = resp.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["name"] == "Accessible Campaign"


@pytest.mark.asyncio
async def test_list_campaigns_specific_project_filter(
    authenticated_user_client: tuple[AsyncClient, User],
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    """Test filtering campaigns by specific project ID."""
    async_client, user = authenticated_user_client

    # Create two projects and associate user with both
    project1 = await project_factory.create_async()
    project2 = await project_factory.create_async()

    assoc1 = ProjectUserAssociation(
        project_id=project1.id, user_id=user.id, role=ProjectUserRole.member
    )
    assoc2 = ProjectUserAssociation(
        project_id=project2.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add_all([assoc1, assoc2])
    await db_session.commit()

    # Create hash lists and campaigns in both projects
    hash_list1 = await hash_list_factory.create_async(project_id=project1.id)
    hash_list2 = await hash_list_factory.create_async(project_id=project2.id)

    await campaign_factory.create_async(
        name="Project 1 Campaign",
        project_id=project1.id,
        hash_list_id=hash_list1.id,
    )
    await campaign_factory.create_async(
        name="Project 2 Campaign",
        project_id=project2.id,
        hash_list_id=hash_list2.id,
    )

    # Test filtering by project1
    resp = await async_client.get(f"/api/v1/control/campaigns?project_id={project1.id}")
    assert resp.status_code == HTTPStatus.OK

    data = resp.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["name"] == "Project 1 Campaign"

    # Test filtering by project2
    resp = await async_client.get(f"/api/v1/control/campaigns?project_id={project2.id}")
    assert resp.status_code == HTTPStatus.OK

    data = resp.json()
    assert data["total"] == 1
    assert len(data["items"]) == 1
    assert data["items"][0]["name"] == "Project 2 Campaign"


@pytest.mark.asyncio
async def test_list_campaigns_unauthorized_project(
    authenticated_user_client: tuple[AsyncClient, User],
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    """Test that accessing unauthorized project returns 403."""
    async_client, user = authenticated_user_client

    # Create two projects, associate user only with project1
    project1 = await project_factory.create_async()
    project2 = await project_factory.create_async()

    assoc = ProjectUserAssociation(
        project_id=project1.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Try to access project2 campaigns
    resp = await async_client.get(f"/api/v1/control/campaigns?project_id={project2.id}")
    assert resp.status_code == HTTPStatus.FORBIDDEN

    data = resp.json()
    assert f"User does not have access to project {project2.id}" in data["detail"]


@pytest.mark.asyncio
async def test_list_campaigns_no_project_access(
    authenticated_user_client: tuple[AsyncClient, User],
    db_session: AsyncSession,
) -> None:
    """Test that user with no project access gets 403."""
    async_client, user = authenticated_user_client

    # User has no project associations
    resp = await async_client.get("/api/v1/control/campaigns")
    assert resp.status_code == HTTPStatus.FORBIDDEN

    data = resp.json()
    assert "User has no project access" in data["detail"]


@pytest.mark.asyncio
async def test_list_campaigns_pagination_limits(
    authenticated_user_client: tuple[AsyncClient, User],
    project_factory: ProjectFactory,
    db_session: AsyncSession,
) -> None:
    """Test pagination parameter validation."""
    async_client, user = authenticated_user_client

    # Create project and associate user
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Test limit too high
    resp = await async_client.get("/api/v1/control/campaigns?limit=101")
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY

    # Test limit too low
    resp = await async_client.get("/api/v1/control/campaigns?limit=0")
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY

    # Test negative offset
    resp = await async_client.get("/api/v1/control/campaigns?offset=-1")
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY


@pytest.mark.asyncio
async def test_list_campaigns_empty_result(
    authenticated_user_client: tuple[AsyncClient, User],
    project_factory: ProjectFactory,
    db_session: AsyncSession,
) -> None:
    """Test listing campaigns when none exist."""
    async_client, user = authenticated_user_client

    # Create project and associate user
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()

    # Test empty result
    resp = await async_client.get("/api/v1/control/campaigns")
    assert resp.status_code == HTTPStatus.OK

    data = resp.json()
    assert data["total"] == 0
    assert data["limit"] == 10
    assert data["offset"] == 0
    assert len(data["items"]) == 0


@pytest.mark.asyncio
async def test_list_campaigns_unauthenticated(
    async_client: AsyncClient,
) -> None:
    """Test that unauthenticated requests are rejected."""
    resp = await async_client.get("/api/v1/control/campaigns")
    assert resp.status_code == HTTPStatus.UNAUTHORIZED
