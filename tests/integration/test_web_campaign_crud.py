from typing import Any
from uuid import uuid4

import pytest
from httpx import AsyncClient


@pytest.mark.asyncio
async def test_list_campaigns_empty(async_client: AsyncClient) -> None:
    resp = await async_client.get("/api/v1/web/campaigns/")
    assert resp.status_code == 200
    assert resp.json() == []


@pytest.mark.asyncio
async def test_create_campaign(
    async_client: AsyncClient, db_session: Any, project_factory: Any
) -> None:
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    payload = {
        "name": "Test Campaign",
        "description": "Integration test campaign",
        "project_id": str(project.id),
    }
    resp = await async_client.post("/api/v1/web/campaigns/", json=payload)
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == payload["name"]
    assert data["description"] == payload["description"]
    assert data["project_id"] == str(project.id)
    assert "id" in data
    assert "created_at" in data
    assert "updated_at" in data


@pytest.mark.asyncio
async def test_get_campaign_success(
    async_client: AsyncClient, db_session: Any, project_factory: Any
) -> None:
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    payload = {
        "name": "Get Campaign",
        "description": "Get test",
        "project_id": str(project.id),
    }
    create_resp = await async_client.post("/api/v1/web/campaigns/", json=payload)
    campaign_id = create_resp.json()["id"]
    resp = await async_client.get(f"/api/v1/web/campaigns/{campaign_id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == campaign_id
    assert data["name"] == payload["name"]


@pytest.mark.asyncio
async def test_get_campaign_not_found(async_client: AsyncClient) -> None:
    fake_id = str(uuid4())
    resp = await async_client.get(f"/api/v1/web/campaigns/{fake_id}")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_update_campaign_success(
    async_client: AsyncClient, db_session: Any, project_factory: Any
) -> None:
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    payload = {
        "name": "Update Campaign",
        "description": "Before update",
        "project_id": str(project.id),
    }
    create_resp = await async_client.post("/api/v1/web/campaigns/", json=payload)
    campaign_id = create_resp.json()["id"]
    update_payload = {"name": "Updated Name", "description": "After update"}
    resp = await async_client.put(
        f"/api/v1/web/campaigns/{campaign_id}", json=update_payload
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == campaign_id
    assert data["name"] == update_payload["name"]
    assert data["description"] == update_payload["description"]


@pytest.mark.asyncio
async def test_update_campaign_not_found(async_client: AsyncClient) -> None:
    fake_id = str(uuid4())
    update_payload = {"name": "Should Not Exist", "description": "Nope"}
    resp = await async_client.put(
        f"/api/v1/web/campaigns/{fake_id}", json=update_payload
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_campaign_success(
    async_client: AsyncClient, db_session: Any, project_factory: Any
) -> None:
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    payload = {
        "name": "Delete Campaign",
        "description": "To be deleted",
        "project_id": str(project.id),
    }
    create_resp = await async_client.post("/api/v1/web/campaigns/", json=payload)
    campaign_id = create_resp.json()["id"]
    resp = await async_client.delete(f"/api/v1/web/campaigns/{campaign_id}")
    assert resp.status_code == 204
    # Confirm deletion
    get_resp = await async_client.get(f"/api/v1/web/campaigns/{campaign_id}")
    assert get_resp.status_code == 404


@pytest.mark.asyncio
async def test_delete_campaign_not_found(async_client: AsyncClient) -> None:
    fake_id = str(uuid4())
    resp = await async_client.delete(f"/api/v1/web/campaigns/{fake_id}")
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_create_campaign_logs(
    async_client: AsyncClient, db_session: Any, project_factory: Any, caplog: Any
) -> None:
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    payload = {
        "name": "Test Campaign Log",
        "description": "Integration test campaign log",
        "project_id": str(project.id),
    }
    with caplog.at_level("INFO"):
        resp = await async_client.post("/api/v1/web/campaigns/", json=payload)
    assert resp.status_code == 201
    assert "Campaign created" in caplog.text


@pytest.mark.asyncio
async def test_campaign_creation_logs_to_logger(
    async_client: AsyncClient, db_session: Any, project_factory: Any, caplog: Any
) -> None:
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    payload = {
        "name": "Log Test Campaign",
        "description": "Should log creation",
        "project_id": str(project.id),
    }
    with caplog.at_level("INFO"):
        resp = await async_client.post("/api/v1/web/campaigns/", json=payload)
    assert resp.status_code == 201
    assert "Campaign created" in caplog.text
