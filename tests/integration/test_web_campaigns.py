from http import HTTPStatus
from typing import Any

import pytest
from httpx import AsyncClient

from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory


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
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["id"] == campaign.id
    assert data["state"] == "active"
    # Stop the campaign
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/stop")
    assert resp.status_code == HTTPStatus.OK
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
    assert resp.status_code == HTTPStatus.OK
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
    assert resp.status_code == HTTPStatus.OK
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
    assert resp.status_code == HTTPStatus.BAD_REQUEST
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/stop")
    assert resp.status_code == HTTPStatus.BAD_REQUEST


@pytest.mark.asyncio
async def test_start_stop_campaign_not_found(async_client: AsyncClient) -> None:
    resp = await async_client.post("/api/v1/web/campaigns/999999/start")
    assert resp.status_code == HTTPStatus.NOT_FOUND
    resp = await async_client.post("/api/v1/web/campaigns/999999/stop")
    assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_create_campaign_web_happy_path(
    async_client: AsyncClient,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    form_data = {
        "name": "Web Campaign Test",
        "description": "Created via web API",
        "project_id": str(project.id),
        "hash_list_id": str(hash_list.id),
        "priority": "1",
    }
    resp = await async_client.post("/api/v1/web/campaigns", data=form_data)
    assert resp.status_code == HTTPStatus.CREATED
    html = resp.text
    assert "Web Campaign Test" in html
    assert "Created via web API" in html


@pytest.mark.asyncio
async def test_create_campaign_web_validation_error(
    async_client: AsyncClient,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    form_data = {
        # Missing name
        "description": "Missing name field",
        "project_id": str(project.id),
        "hash_list_id": str(hash_list.id),
        "priority": "1",
    }
    resp = await async_client.post("/api/v1/web/campaigns", data=form_data)
    assert resp.status_code == HTTPStatus.BAD_REQUEST
    html = resp.text
    assert "Name is required" in html or "name" in html.lower()


@pytest.mark.asyncio
async def test_campaign_detail_view(
    async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    attack_factory: Any,
) -> None:
    """Test the campaign detail endpoint returns correct HTML fragment with attacks."""
    import re

    # Setup: create project, hash list, campaign, and attack
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="active", project_id=project.id, hash_list_id=hash_list.id
    )
    # Attach an attack to the campaign
    attack = await attack_factory.create_async(
        campaign_id=campaign.id, name="Test Attack", attack_mode="dictionary"
    )
    # Fetch the detail endpoint
    resp = await async_client.get(f"/api/v1/web/campaigns/{campaign.id}")
    assert resp.status_code == HTTPStatus.OK
    html = resp.text
    # Validate campaign fields
    assert campaign.name in html
    assert (campaign.description or "") in html or "Description" in html
    # Validate attack summary table
    assert "Attacks" in html
    assert attack.name in html
    assert re.search(r"<td[^>]*>dictionary</td>", html, re.IGNORECASE)
    # Should show keyspace, complexity, comment columns
    assert "Keyspace" in html
    assert "Complexity" in html
    assert "Comment" in html


@pytest.mark.asyncio
async def test_campaign_detail_not_found(async_client: AsyncClient) -> None:
    resp = await async_client.get("/api/v1/web/campaigns/999999")
    assert resp.status_code == HTTPStatus.NOT_FOUND
