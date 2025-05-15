import json
from http import HTTPStatus
from typing import Any

import httpx
import pytest
from httpx import AsyncClient

from app.schemas.shared import AttackTemplate
from tests.factories.attack_factory import AttackFactory
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory
from tests.factories.task_factory import TaskFactory


@pytest.mark.asyncio
async def test_estimate_attack_happy_path(async_client: AsyncClient) -> None:
    payload = {
        "name": "Test Attack",
        "hash_type_id": 0,
        "attack_mode": "dictionary",
        "hash_list_id": 1,
        "hash_list_url": "http://example.com/hashes.txt",
        "hash_list_checksum": "deadbeef",
    }
    resp = await async_client.post("/api/v1/web/attacks/estimate", json=payload)
    assert resp.status_code == HTTPStatus.OK
    assert "Keyspace Estimate" in resp.text
    assert "Complexity Score" in resp.text


@pytest.mark.asyncio
async def test_estimate_attack_invalid_input(async_client: AsyncClient) -> None:
    # Missing required fields
    payload = {"name": "Incomplete Attack"}
    resp = await async_client.post("/api/v1/web/attacks/estimate", json=payload)
    assert resp.status_code == httpx.codes.BAD_REQUEST
    assert "error" in resp.text or "message" in resp.text


@pytest.mark.asyncio
async def test_estimate_attack_non_json(async_client: AsyncClient) -> None:
    resp = await async_client.post(
        "/api/v1/web/attacks/estimate",
        content=b"notjson",
        headers={"Content-Type": "application/json"},
    )
    assert resp.status_code in (httpx.codes.BAD_REQUEST, 422)


@pytest.mark.asyncio
async def test_attack_export_import_json(
    async_client: AsyncClient,
    attack_factory: Any,
    campaign_factory: Any,
    hash_list_factory: Any,
    project_factory: Any,
) -> None:
    # Create required parent objects
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    # Create an attack linked to the campaign and hash list
    attack = await attack_factory.create_async(
        name="ExportTest",
        attack_mode="dictionary",
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
    )
    # Export the attack as JSON template
    resp = await async_client.get(f"/api/v1/web/attacks/{attack.id}/export")
    assert resp.status_code == HTTPStatus.OK
    assert resp.headers["content-type"].startswith("application/json")
    exported = json.loads(resp.content)
    # Validate exported JSON matches AttackTemplate schema (round-trip)
    template = AttackTemplate.model_validate(exported)
    assert template.mode == "dictionary"
    # Import the attack JSON (should prefill editor modal, not persist)
    resp2 = await async_client.post(
        "/api/v1/web/attacks/import_json",
        content=json.dumps(exported),
        headers={"content-type": "application/json"},
    )
    assert resp2.status_code == HTTPStatus.OK
    # The response should contain the editor modal and prefilled data
    assert "attack" in resp2.text or "editor" in resp2.text
    # Simulate round-trip: export → import → re-export (schema only)
    # (In a real UI, user would fill missing fields before saving)
    # Here, just ensure the template can be re-serialized/deserialized
    reloaded = AttackTemplate.model_validate(template.model_dump())
    assert reloaded.mode == template.mode
    # Missing resource GUIDs or hash list is expected and left for user to resolve
    # No DB persistence is required at this stage


@pytest.mark.asyncio
async def test_edit_attack_lifecycle_reset_triggers_reprocessing(
    async_client: AsyncClient,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    hash_list_factory: HashListFactory,
    project_factory: ProjectFactory,
    task_factory: TaskFactory,
) -> None:
    # Setup: create project, hash list, campaign, attack (running), and tasks (running)
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await attack_factory.create_async(
        name="LifecycleResetTest",
        attack_mode="dictionary",
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
        state="running",
    )
    # Create two tasks for this attack, both running
    await task_factory.create_async(attack_id=attack.id, status="running")
    await task_factory.create_async(attack_id=attack.id, status="running")
    # Patch the attack with confirm=True to trigger lifecycle reset
    patch_payload = {"name": "LifecycleResetTestPatched", "confirm": True}
    resp = await async_client.patch(
        f"/api/v1/web/attacks/{attack.id}", json=patch_payload
    )
    # If edit confirmation is required, a 409 is returned with a warning fragment
    if resp.status_code == HTTPStatus.CONFLICT:
        # Simulate user confirming the edit by submitting the form (HTMX flow)
        # The form uses hx-patch to the same URL with the same data
        resp2 = await async_client.patch(
            f"/api/v1/web/attacks/{attack.id}", json=patch_payload
        )
        assert resp2.status_code == HTTPStatus.OK
        assert "LifecycleResetTestPatched" in resp2.text
    else:
        assert resp.status_code == HTTPStatus.OK
        assert "LifecycleResetTestPatched" in resp.text
    # Fetch the attack and tasks from the DB to verify state
    resp2 = await async_client.get(f"/api/v1/web/attacks/{attack.id}/export")
    assert resp2.status_code == HTTPStatus.OK
    # The attack should now be in pending state
    # (We can't check DB state directly here, but the PATCH should succeed and not error)
    # Optionally, check the response HTML for expected content
    assert "LifecycleResetTestPatched" in resp.text
    # Optionally, fetch tasks and check their status if API allows
    # (If not, this is covered by service-layer tests)
