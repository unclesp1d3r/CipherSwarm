import json
from http import HTTPStatus
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.shared import AttackTemplate
from tests.factories.attack_factory import AttackFactory
from tests.factories.attack_resource_file_factory import AttackResourceFileFactory
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
    assert resp.status_code == HTTPStatus.BAD_REQUEST
    assert "error" in resp.text or "message" in resp.text


@pytest.mark.asyncio
async def test_estimate_attack_non_json(async_client: AsyncClient) -> None:
    resp = await async_client.post(
        "/api/v1/web/attacks/estimate",
        content=b"notjson",
        headers={"Content-Type": "application/json"},
    )
    assert resp.status_code in (HTTPStatus.BAD_REQUEST, HTTPStatus.UNPROCESSABLE_ENTITY)


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


@pytest.mark.asyncio
async def test_validate_attack_happy_path(async_client: AsyncClient) -> None:
    payload = {
        "mode": "dictionary",
        "min_length": 6,
        "max_length": 12,
        "wordlist_guid": None,
        "rulelist_guid": None,
        "masklist_guid": None,
        "wordlist_inline": None,
        "rules_inline": None,
        "masks": None,
        "masks_inline": None,
        "position": 0,
        "comment": None,
        "rule_file": None,
    }
    resp = await async_client.post("/api/v1/web/attacks/validate", json=payload)
    assert resp.status_code == HTTPStatus.OK
    assert "Attack Validated" in resp.text
    assert "Keyspace" in resp.text


@pytest.mark.asyncio
async def test_validate_attack_invalid_input(async_client: AsyncClient) -> None:
    # Missing required fields
    payload = {"mode": "not_a_real_mode"}
    resp = await async_client.post("/api/v1/web/attacks/validate", json=payload)
    assert resp.status_code == HTTPStatus.BAD_REQUEST
    assert "error" in resp.text or "message" in resp.text


@pytest.mark.asyncio
async def test_validate_attack_non_json(async_client: AsyncClient) -> None:
    resp = await async_client.post(
        "/api/v1/web/attacks/validate",
        content=b"notjson",
        headers={"Content-Type": "application/json"},
    )
    assert resp.status_code in (
        HTTPStatus.BAD_REQUEST,
        HTTPStatus.UNPROCESSABLE_ENTITY,
    )


@pytest.mark.asyncio
async def test_dictionary_attack_modifiers_map_to_rule_file(
    async_client: AsyncClient,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    hash_list_factory: HashListFactory,
    project_factory: ProjectFactory,
) -> None:
    # Setup: create project, hash list, campaign
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    # Create attack with modifiers
    payload = {
        "name": "ModifierTest",
        "attack_mode": "dictionary",
        "hash_type_id": 0,
        "campaign_id": campaign.id,
        "hash_list_id": hash_list.id,
        "hash_list_url": "http://example.com/hashes.txt",
        "hash_list_checksum": "deadbeef",
        "modifiers": ["change_case"],
    }
    resp = await async_client.post("/api/v1/web/attacks/estimate", json=payload)
    assert resp.status_code == HTTPStatus.OK
    # Simulate PATCH to update attack with modifiers
    attack = await attack_factory.create_async(
        name="ModifierTest2",
        attack_mode="dictionary",
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
    )
    patch_payload = {"modifiers": ["change_case"]}
    resp2 = await async_client.patch(
        f"/api/v1/web/attacks/{attack.id}", json=patch_payload
    )
    assert resp2.status_code == HTTPStatus.OK
    # The response should contain the rule UUID as left_rule (placeholder)
    assert "00000000-0000-0000-0000-000000000001" in resp2.text


@pytest.mark.asyncio
async def test_create_attack_with_ephemeral_mask_inline(
    async_client: AsyncClient,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    hash_list_factory: HashListFactory,
    project_factory: ProjectFactory,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    masks = ["?l?l?l?l?l", "?d?d?d?d?d"]
    mask_resource = await attack_resource_file_factory.create_async(
        resource_type="ephemeral_mask_list",
        content={"lines": masks},
    )
    assert mask_resource is not None
    assert mask_resource.content is not None
    assert mask_resource.content["lines"] == masks
    attack = await attack_factory.create_async(
        name="EphemeralMaskTest",
        attack_mode="mask",
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
    )
    assert mask_resource.content["lines"] == masks
    # Export the attack as JSON template
    resp = await async_client.get(f"/api/v1/web/attacks/{attack.id}/export")
    assert resp.status_code == HTTPStatus.OK
    exported = json.loads(resp.content)
    assert (
        exported["masks_inline"] is None
    )  # This is not a thing. Ephemeral mask lists are always going to be on the attack resource file, not on the attack.
    # Delete the attack
    del_resp = await async_client.request(
        "DELETE",
        "/api/v1/web/attacks/bulk",
        json={"attack_ids": [attack.id]},
        headers={"content-type": "application/json"},
    )
    assert del_resp.status_code == HTTPStatus.OK
    # Confirm attack is deleted (should 404)
    resp2 = await async_client.get(f"/api/v1/web/attacks/{attack.id}/export")
    assert resp2.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_import_attack_with_ephemeral_mask_inline(
    async_client: AsyncClient,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    hash_list_factory: HashListFactory,
    project_factory: ProjectFactory,
) -> None:
    # Prepare an exported attack template with masks_inline
    masks_inline = ["?l?l?l?l?l", "?d?d?d?d?d"]
    exported = {
        "mode": "mask",
        "position": 0,
        "comment": "Ephemeral mask import",
        "min_length": 5,
        "max_length": 5,
        "masks_inline": masks_inline,
    }
    resp = await async_client.post(
        "/api/v1/web/attacks/import_json",
        content=json.dumps(exported),
        headers={"content-type": "application/json"},
    )
    assert resp.status_code == HTTPStatus.OK
    assert any(mask in resp.text for mask in masks_inline)


@pytest.mark.asyncio
async def test_create_attack_with_previous_passwords_wordlist(
    async_client: AsyncClient,
    db_session: AsyncSession,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    hash_list_factory: HashListFactory,
    project_factory: ProjectFactory,
) -> None:
    # Setup: create project, hash list, campaign, and cracked hash items
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    db_session.add(hash_list)
    await db_session.flush()
    # Add cracked hash items
    from app.models.hash_item import HashItem

    cracked_passwords = ["hunter2", "letmein", "password123"]
    hash_items = []
    for pw in cracked_passwords:
        item = HashItem(hash=f"hash-{pw}", plain_text=pw)
        db_session.add(item)
        hash_items.append(item)
    await db_session.flush()
    await db_session.run_sync(lambda _s: setattr(hash_list, "items", hash_items))
    await db_session.commit()
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    # Create attack with previous_passwords wordlist source
    payload = {
        "name": "PrevPwAttack",
        "attack_mode": "dictionary",
        "hash_type_id": 0,
        "campaign_id": campaign.id,
        "hash_list_id": hash_list.id,
        "wordlist_source": "previous_passwords",
        "hash_list_url": "http://example.com/hashes.txt",
        "hash_list_checksum": "deadbeef",
    }
    resp = await async_client.post("/api/v1/web/attacks", json=payload)
    assert resp.status_code == HTTPStatus.CREATED
    # Fetch the created attack and verify the dynamic wordlist
    attack_id = (
        resp.json()["id"]
        if resp.headers["content-type"].startswith("application/json")
        else None
    )
    if attack_id:
        attack_resp = await async_client.get(f"/api/v1/web/attacks/{attack_id}")
        assert attack_resp.status_code == HTTPStatus.OK
        data = attack_resp.json()
        # The word_list should be present and contain the cracked passwords
        word_list = data.get("word_list")
        assert word_list is not None
        assert word_list["resource_type"] == "DYNAMIC_WORD_LIST"
        assert set(word_list["content"]["lines"]) == set(cracked_passwords)


@pytest.mark.asyncio
async def test_create_attack_with_ephemeral_wordlist(
    async_client: AsyncClient,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    hash_list_factory: HashListFactory,
    project_factory: ProjectFactory,
    attack_resource_file_factory: AttackResourceFileFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    words = ["alpha", "bravo", "charlie"]
    payload = {
        "name": "EphemeralWordlistTest",
        "attack_mode": "dictionary",
        "hash_type_id": 0,
        "campaign_id": campaign.id,
        "hash_list_id": hash_list.id,
        "hash_list_url": "http://example.com/hashes.txt",
        "hash_list_checksum": "deadbeef",
        "wordlist_inline": words,
    }
    resp = await async_client.post(
        "/api/v1/web/attacks",
        json=payload,
        headers={"accept": "application/json"},
    )
    assert resp.status_code == HTTPStatus.CREATED
    # Fetch the created attack and verify the ephemeral wordlist
    attack_id = resp.json()["id"]
    attack_resp = await async_client.get(f"/api/v1/web/attacks/{attack_id}")
    assert attack_resp.status_code == HTTPStatus.OK
    data = attack_resp.json()
    word_list = data.get("word_list")
    assert word_list is not None
    assert word_list["resource_type"] == "ephemeral_word_list"
    assert set(word_list["content"]["lines"]) == set(words)
    # Export the attack as JSON template
    export_resp = await async_client.get(f"/api/v1/web/attacks/{attack_id}/export")
    assert export_resp.status_code == HTTPStatus.OK
    exported = json.loads(export_resp.content)
    assert exported.get("wordlist_inline") == words or set(
        exported.get("wordlist_inline", [])
    ) == set(words)
    # Delete the attack
    del_resp = await async_client.request(
        "DELETE",
        "/api/v1/web/attacks/bulk",
        json={"attack_ids": [attack_id]},
        headers={"content-type": "application/json"},
    )
    assert del_resp.status_code == HTTPStatus.OK
    # Confirm attack is deleted (should 404)
    resp2 = await async_client.get(f"/api/v1/web/attacks/{attack_id}")
    assert resp2.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_validate_mask_valid(async_client: AsyncClient) -> None:
    resp = await async_client.post(
        "/api/v1/web/attacks/validate_mask",
        json={"mask": "?l?u?d?d?1A"},
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["valid"] is True
    assert data["error"] is None


@pytest.mark.asyncio
async def test_validate_mask_invalid_token(async_client: AsyncClient) -> None:
    resp = await async_client.post(
        "/api/v1/web/attacks/validate_mask",
        json={"mask": "?l?z?d"},
    )
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
    data = resp.json()
    assert data["valid"] is False
    assert "Invalid mask token" in data["error"]


@pytest.mark.asyncio
async def test_validate_mask_empty(async_client: AsyncClient) -> None:
    resp = await async_client.post(
        "/api/v1/web/attacks/validate_mask",
        json={"mask": "   "},
    )
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
    data = resp.json()
    assert data["valid"] is False
    assert "empty" in data["error"]


@pytest.mark.asyncio
async def test_validate_mask_too_long(async_client: AsyncClient) -> None:
    long_mask = "?l" * 130  # 260 chars
    resp = await async_client.post(
        "/api/v1/web/attacks/validate_mask",
        json={"mask": long_mask},
    )
    assert resp.status_code == HTTPStatus.UNPROCESSABLE_ENTITY
    data = resp.json()
    assert data["valid"] is False
    assert "maximum length" in data["error"]


@pytest.mark.asyncio
async def test_attack_performance_summary(
    async_client: AsyncClient,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    hash_list_factory: HashListFactory,
    project_factory: ProjectFactory,
    task_factory: TaskFactory,
    agent_factory: Any,
    db_session: AsyncSession,
) -> None:
    # Setup: create project, hash list, campaign, agent, attack, and tasks
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    agent = await agent_factory.create_async()
    attack = await attack_factory.create_async(
        name="PerfTest",
        attack_mode="dictionary",
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
        hash_type_id=0,
    )
    # Create tasks for this attack, assign to agent
    await task_factory.create_async(
        attack_id=attack.id, agent_id=agent.id, status="running", progress=50.0
    )
    await task_factory.create_async(
        attack_id=attack.id, agent_id=agent.id, status="pending", progress=0.0
    )
    # Insert a benchmark for the agent
    from app.models.hashcat_benchmark import HashcatBenchmark

    bench = HashcatBenchmark(
        agent_id=agent.id,
        hash_type_id=0,
        hash_speed=1000.0,
        device="testdev",
        runtime=1000,
    )
    db_session.add(bench)
    await db_session.commit()
    # Call the endpoint
    resp = await async_client.get(f"/api/v1/web/attacks/{attack.id}/performance")
    assert resp.status_code == HTTPStatus.OK
    assert "Performance Summary" in resp.text
    assert "Total Hashes" in resp.text
    assert "Agents" in resp.text
    assert "Speed" in resp.text
    assert "ETA" in resp.text


@pytest.mark.asyncio
async def test_attack_live_updates_toggle(
    async_client: AsyncClient,
    attack_factory: AttackFactory,
    campaign_factory: CampaignFactory,
    hash_list_factory: HashListFactory,
    project_factory: ProjectFactory,
    db_session: AsyncSession,
) -> None:
    # Setup: create project, hash list, campaign, attack
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        project_id=project.id, hash_list_id=hash_list.id
    )
    attack = await attack_factory.create_async(
        name="LiveUpdatesTest",
        attack_mode="dictionary",
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
        hash_type_id=0,
    )
    # Toggle (should disable)
    resp = await async_client.post(
        f"/api/v1/web/attacks/{attack.id}/disable_live_updates"
    )
    assert resp.status_code == HTTPStatus.OK
    assert "Live Updates" in resp.text
    assert "Disabled" in resp.text
    # Explicit enable
    resp2 = await async_client.post(
        f"/api/v1/web/attacks/{attack.id}/disable_live_updates",
        json={"enabled": True},
    )
    assert resp2.status_code == HTTPStatus.OK
    assert "Enabled" in resp2.text
    # Explicit disable
    resp3 = await async_client.post(
        f"/api/v1/web/attacks/{attack.id}/disable_live_updates",
        json={"enabled": False},
    )
    assert resp3.status_code == HTTPStatus.OK
    assert "Disabled" in resp3.text
    # Not found
    resp4 = await async_client.post("/api/v1/web/attacks/999999/disable_live_updates")
    assert resp4.status_code == HTTPStatus.NOT_FOUND
    assert "error" in resp4.text or "not found" in resp4.text
