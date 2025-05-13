import pytest
from httpx import AsyncClient

from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory

HTTP_200_OK = 200
HTTP_404_NOT_FOUND = 404
HTTP_400_BAD_REQUEST = 400


@pytest.mark.asyncio
async def test_start_stop_campaign_happy_path(
    async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="draft", project_id=project.id, hash_list_id=hash_list.id
    )
    # Start the campaign
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/start")
    assert resp.status_code == HTTP_200_OK
    data = resp.json()
    assert data["id"] == campaign.id
    assert data["state"] == "active"
    # Stop the campaign
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/stop")
    assert resp.status_code == HTTP_200_OK
    data = resp.json()
    assert data["id"] == campaign.id
    assert data["state"] == "draft"


@pytest.mark.asyncio
async def test_start_campaign_already_active(
    async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="active", project_id=project.id, hash_list_id=hash_list.id
    )
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/start")
    assert resp.status_code == HTTP_200_OK
    data = resp.json()
    assert data["id"] == campaign.id
    assert data["state"] == "active"


@pytest.mark.asyncio
async def test_stop_campaign_already_draft(
    async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="draft", project_id=project.id, hash_list_id=hash_list.id
    )
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/stop")
    assert resp.status_code == HTTP_200_OK
    data = resp.json()
    assert data["id"] == campaign.id
    assert data["state"] == "draft"


@pytest.mark.asyncio
async def test_start_stop_campaign_archived(
    async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="archived", project_id=project.id, hash_list_id=hash_list.id
    )
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/start")
    assert resp.status_code == HTTP_400_BAD_REQUEST
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/stop")
    assert resp.status_code == HTTP_400_BAD_REQUEST


@pytest.mark.asyncio
async def test_start_stop_campaign_not_found(async_client: AsyncClient) -> None:
    resp = await async_client.post("/api/v1/web/campaigns/999999/start")
    assert resp.status_code == HTTP_404_NOT_FOUND
    resp = await async_client.post("/api/v1/web/campaigns/999999/stop")
    assert resp.status_code == HTTP_404_NOT_FOUND
