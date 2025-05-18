import json
from http import HTTPStatus
from typing import Any

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload

from app.models.project import ProjectUserAssociation, ProjectUserRole
from app.models.user import User
from app.schemas.shared import CampaignTemplate
from tests.factories.campaign_factory import CampaignFactory
from tests.factories.hash_list_factory import HashListFactory
from tests.factories.project_factory import ProjectFactory

CRACKED_THRESHOLD = 2


@pytest.mark.asyncio
async def test_start_stop_campaign_happy_path(
    authenticated_user_client: tuple[AsyncClient, User],
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    async_client, user = authenticated_user_client
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="draft", project_id=project.id, hash_list_id=hash_list.id
    )
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/start")
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["id"] == campaign.id
    assert data["state"] == "active"
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/stop")
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["id"] == campaign.id
    assert data["state"] == "draft"


@pytest.mark.asyncio
async def test_start_campaign_already_active(
    authenticated_user_client: tuple[AsyncClient, User],
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    async_client, user = authenticated_user_client
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()
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
    authenticated_user_client: tuple[AsyncClient, User],
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    async_client, user = authenticated_user_client
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()
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
    authenticated_user_client: tuple[AsyncClient, User],
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    db_session: AsyncSession,
) -> None:
    async_client, user = authenticated_user_client
    project = await project_factory.create_async()
    assoc = ProjectUserAssociation(
        project_id=project.id, user_id=user.id, role=ProjectUserRole.member
    )
    db_session.add(assoc)
    await db_session.commit()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="archived", project_id=project.id, hash_list_id=hash_list.id
    )
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/start")
    assert resp.status_code == HTTPStatus.BAD_REQUEST
    resp = await async_client.post(f"/api/v1/web/campaigns/{campaign.id}/stop")
    assert resp.status_code == HTTPStatus.BAD_REQUEST


@pytest.mark.asyncio
async def test_start_stop_campaign_not_found(
    authenticated_async_client: AsyncClient,
) -> None:
    resp = await authenticated_async_client.post("/api/v1/web/campaigns/999999/start")
    assert resp.status_code == HTTPStatus.NOT_FOUND
    resp = await authenticated_async_client.post("/api/v1/web/campaigns/999999/stop")
    assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_create_campaign_web_happy_path(
    authenticated_async_client: AsyncClient,
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
    resp = await authenticated_async_client.post(
        "/api/v1/web/campaigns", data=form_data
    )
    assert resp.status_code == HTTPStatus.CREATED
    html = resp.text
    assert "Web Campaign Test" in html
    assert "Created via web API" in html


@pytest.mark.asyncio
async def test_create_campaign_web_validation_error(
    authenticated_async_client: AsyncClient,
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
    resp = await authenticated_async_client.post(
        "/api/v1/web/campaigns", data=form_data
    )
    assert resp.status_code in {HTTPStatus.UNPROCESSABLE_ENTITY, HTTPStatus.BAD_REQUEST}
    html = resp.text
    assert "Name is required" in html or "name" in html.lower()


@pytest.mark.asyncio
async def test_campaign_detail_view(
    authenticated_async_client: AsyncClient,
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
    resp = await authenticated_async_client.get(f"/api/v1/web/campaigns/{campaign.id}")
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
async def test_campaign_detail_not_found(
    authenticated_async_client: AsyncClient,
) -> None:
    resp = await authenticated_async_client.get("/api/v1/web/campaigns/999999")
    assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_archive_campaign_happy_path(
    authenticated_async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="active", project_id=project.id, hash_list_id=hash_list.id
    )
    # Archive the campaign
    resp = await authenticated_async_client.delete(
        f"/api/v1/web/campaigns/{campaign.id}"
    )
    assert resp.status_code == HTTPStatus.OK
    html = resp.text
    assert campaign.name not in html  # Should not appear in list after archival


@pytest.mark.asyncio
async def test_archive_campaign_not_found(
    authenticated_async_client: AsyncClient,
) -> None:
    resp = await authenticated_async_client.delete("/api/v1/web/campaigns/999999")
    assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_archive_campaign_already_archived(
    authenticated_async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="archived", project_id=project.id, hash_list_id=hash_list.id
    )
    resp = await authenticated_async_client.delete(
        f"/api/v1/web/campaigns/{campaign.id}"
    )
    assert resp.status_code in {HTTPStatus.OK, HTTPStatus.NO_CONTENT}


@pytest.mark.asyncio
async def test_add_attack_to_campaign_happy_path(
    authenticated_async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="active", project_id=project.id, hash_list_id=hash_list.id
    )
    attack_data = {
        "name": "New Attack",
        "description": "Test attack",
        "state": "pending",
        "hash_type_id": 0,
        "attack_mode": "dictionary",
        "attack_mode_hashcat": 0,
        "hash_mode": 0,
        "mask": None,
        "increment_mode": False,
        "increment_minimum": 0,
        "increment_maximum": 0,
        "optimized": False,
        "slow_candidate_generators": False,
        "workload_profile": 3,
        "disable_markov": False,
        "classic_markov": False,
        "markov_threshold": 0,
        "left_rule": None,
        "right_rule": None,
        "custom_charset_1": None,
        "custom_charset_2": None,
        "custom_charset_3": None,
        "custom_charset_4": None,
        "hash_list_id": hash_list.id,
        "hash_list_url": "http://example.com/hashlist",
        "hash_list_checksum": "abc123",
        "priority": 0,
        "position": 0,
        "start_time": None,
        "end_time": None,
        "campaign_id": None,
        "template_id": None,
    }
    resp = await authenticated_async_client.post(
        f"/api/v1/web/campaigns/{campaign.id}/add_attack",
        json=attack_data,
    )
    assert resp.status_code == HTTPStatus.CREATED
    html = resp.text
    assert "New Attack" in html
    assert "Test attack" in html or "Attacks" in html


@pytest.mark.asyncio
async def test_add_attack_to_campaign_validation_error(
    authenticated_async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="active", project_id=project.id, hash_list_id=hash_list.id
    )
    # Missing required field 'name'
    attack_data = {
        # "name": "Missing Name",
        "description": "No name",
        "state": "pending",
        "hash_type_id": 0,
        "attack_mode": "dictionary",
        "attack_mode_hashcat": 0,
        "hash_mode": 0,
        "mask": None,
        "increment_mode": False,
        "increment_minimum": 0,
        "increment_maximum": 0,
        "optimized": False,
        "slow_candidate_generators": False,
        "workload_profile": 3,
        "disable_markov": False,
        "classic_markov": False,
        "markov_threshold": 0,
        "left_rule": None,
        "right_rule": None,
        "custom_charset_1": None,
        "custom_charset_2": None,
        "custom_charset_3": None,
        "custom_charset_4": None,
        "hash_list_id": hash_list.id,
        "hash_list_url": "http://example.com/hashlist",
        "hash_list_checksum": "abc123",
        "priority": 0,
        "position": 0,
        "start_time": None,
        "end_time": None,
        "campaign_id": None,
        "template_id": None,
    }
    resp = await authenticated_async_client.post(
        f"/api/v1/web/campaigns/{campaign.id}/add_attack",
        json=attack_data,
    )
    assert resp.status_code in {HTTPStatus.UNPROCESSABLE_ENTITY, HTTPStatus.BAD_REQUEST}


@pytest.mark.asyncio
async def test_add_attack_to_campaign_not_found(
    authenticated_async_client: AsyncClient,
) -> None:
    attack_data = {
        "name": "Should Fail",
        "description": "No campaign",
        "state": "pending",
        "hash_type_id": 0,
        "attack_mode": "dictionary",
        "attack_mode_hashcat": 0,
        "hash_mode": 0,
        "mask": None,
        "increment_mode": False,
        "increment_minimum": 0,
        "increment_maximum": 0,
        "optimized": False,
        "slow_candidate_generators": False,
        "workload_profile": 3,
        "disable_markov": False,
        "classic_markov": False,
        "markov_threshold": 0,
        "left_rule": None,
        "right_rule": None,
        "custom_charset_1": None,
        "custom_charset_2": None,
        "custom_charset_3": None,
        "custom_charset_4": None,
        "hash_list_id": 1,
        "hash_list_url": "http://example.com/hashlist",
        "hash_list_checksum": "abc123",
        "priority": 0,
        "position": 0,
        "start_time": None,
        "end_time": None,
        "campaign_id": None,
        "template_id": None,
    }
    resp = await authenticated_async_client.post(
        "/api/v1/web/campaigns/999999/add_attack",
        json=attack_data,
    )
    assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_campaign_progress_fragment_happy_path(
    authenticated_async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="active", project_id=project.id, hash_list_id=hash_list.id
    )
    resp = await authenticated_async_client.get(
        f"/api/v1/web/campaigns/{campaign.id}/progress"
    )
    assert resp.status_code == HTTPStatus.OK
    html = resp.text
    assert "Active Agents:" in html
    assert "Total Tasks:" in html
    # Should show 0 for both in a new campaign
    assert ">0<" in html  # at least one zero value


@pytest.mark.asyncio
async def test_campaign_progress_fragment_not_found(
    authenticated_async_client: AsyncClient,
) -> None:
    resp = await authenticated_async_client.get("/api/v1/web/campaigns/999999/progress")
    assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_campaign_metrics_fragment_happy_path(
    authenticated_async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    db_session: "AsyncSession",
) -> None:
    # Setup: create project, hash list, campaign, and hash items
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    from app.models.hash_item import HashItem

    # Create and persist hash items
    hash_items = [
        HashItem(
            hash=f"hash{i}", plain_text=(f"pw{i}" if i < CRACKED_THRESHOLD else None)
        )
        for i in range(5)
    ]
    db_session.add_all(hash_items)
    await db_session.commit()

    # Reload hash_list with selectinload, extend items, add and commit
    result = await db_session.execute(
        select(hash_list.__class__)
        .options(selectinload(hash_list.__class__.items))
        .where(hash_list.__class__.id == hash_list.id)
    )
    hash_list_db = result.scalar_one_or_none()
    assert hash_list_db is not None, "hash_list not found in session after commit"
    hash_list_db.items = list(hash_items)
    db_session.add(hash_list_db)
    await db_session.commit()
    await db_session.refresh(hash_list_db)

    # Now create the campaign
    campaign = await campaign_factory.create_async(
        state="active", project_id=project.id, hash_list_id=hash_list.id
    )
    resp = await authenticated_async_client.get(
        f"/api/v1/web/campaigns/{campaign.id}/metrics"
    )
    assert resp.status_code == HTTPStatus.OK
    html = resp.text
    assert "Total Hashes" in html
    assert ">5<" in html  # total
    assert ">2<" in html  # cracked
    assert ">3<" in html  # uncracked
    assert "%" in html  # percent cracked
    assert "progress" in html or "Progress" in html


@pytest.mark.asyncio
async def test_campaign_metrics_fragment_not_found(
    authenticated_async_client: AsyncClient,
) -> None:
    resp = await authenticated_async_client.get("/api/v1/web/campaigns/999999/metrics")
    assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_relaunch_campaign_resets_failed_attacks(
    authenticated_async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    attack_factory: Any,
    db_session: AsyncSession,
) -> None:
    # Setup: create campaign with one failed and one completed attack
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="active", project_id=project.id, hash_list_id=hash_list.id
    )
    failed_attack = await attack_factory.create_async(
        campaign_id=campaign.id, name="Failed Attack", state="failed"
    )
    completed_attack = await attack_factory.create_async(
        campaign_id=campaign.id, name="Completed Attack", state="completed"
    )
    # Add a failed task to the failed attack
    from app.models.task import Task, TaskStatus

    task = Task(
        attack_id=failed_attack.id,
        agent_id=None,
        start_date=failed_attack.start_time
        or failed_attack.end_time
        or hash_list.created_at,
        status=TaskStatus.FAILED,
        progress=50.0,
    )
    db_session.add(task)
    await db_session.commit()
    # Relaunch
    resp = await authenticated_async_client.post(
        f"/api/v1/web/campaigns/{campaign.id}/relaunch"
    )
    assert resp.status_code == HTTPStatus.OK
    html = resp.text
    assert "Failed Attack" in html
    assert "Completed Attack" in html
    # Check DB: failed attack and its task are now pending
    from sqlalchemy.future import select

    from app.models.attack import Attack, AttackState
    from app.models.task import Task as TaskModel
    from app.models.task import TaskStatus

    attack_obj = (
        await db_session.execute(select(Attack).where(Attack.id == failed_attack.id))
    ).scalar_one()
    assert attack_obj.state == AttackState.PENDING
    task_obj = (
        await db_session.execute(
            select(TaskModel).where(TaskModel.attack_id == failed_attack.id)
        )
    ).scalar_one()
    assert task_obj.status == TaskStatus.PENDING
    # Completed attack is unchanged
    completed_obj = (
        await db_session.execute(select(Attack).where(Attack.id == completed_attack.id))
    ).scalar_one()
    assert completed_obj.state == AttackState.COMPLETED


@pytest.mark.asyncio
async def test_relaunch_campaign_no_failed_attacks(
    authenticated_async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
    attack_factory: Any,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="active", project_id=project.id, hash_list_id=hash_list.id
    )
    await attack_factory.create_async(
        campaign_id=campaign.id, name="Completed Attack", state="completed"
    )
    resp = await authenticated_async_client.post(
        f"/api/v1/web/campaigns/{campaign.id}/relaunch"
    )
    assert resp.status_code == HTTPStatus.BAD_REQUEST
    html = resp.text
    assert "No failed or modified attacks to relaunch" in html


@pytest.mark.asyncio
async def test_relaunch_campaign_archived(
    authenticated_async_client: AsyncClient,
    campaign_factory: CampaignFactory,
    project_factory: ProjectFactory,
    hash_list_factory: HashListFactory,
) -> None:
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    campaign = await campaign_factory.create_async(
        state="archived", project_id=project.id, hash_list_id=hash_list.id
    )
    resp = await authenticated_async_client.post(
        f"/api/v1/web/campaigns/{campaign.id}/relaunch"
    )
    assert resp.status_code == HTTPStatus.BAD_REQUEST
    html = resp.text
    assert "Cannot relaunch an archived campaign" in html


@pytest.mark.asyncio
async def test_relaunch_campaign_not_found(
    authenticated_async_client: AsyncClient,
) -> None:
    resp = await authenticated_async_client.post(
        "/api/v1/web/campaigns/999999/relaunch"
    )
    assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_campaign_export_import_json(
    authenticated_async_client: AsyncClient,
    campaign_factory: Any,
    project_factory: Any,
    hash_list_factory: Any,
) -> None:
    # Create required parent objects
    project = await project_factory.create_async()
    hash_list = await hash_list_factory.create_async(project_id=project.id)
    # Create a campaign linked to the project and hash list
    campaign = await campaign_factory.create_async(
        name="ExportCamp",
        description="Export test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    # Export the campaign as JSON template
    resp = await authenticated_async_client.get(
        f"/api/v1/web/campaigns/{campaign.id}/export"
    )
    assert resp.status_code == HTTPStatus.OK
    assert resp.headers["content-type"].startswith("application/json")
    exported = json.loads(resp.content)
    # Validate exported JSON matches CampaignTemplate schema (round-trip)
    template = CampaignTemplate.model_validate(exported)
    assert template.name == "ExportCamp"
    # Import the campaign JSON (should prefill editor modal, not persist)
    resp2 = await authenticated_async_client.post(
        "/api/v1/web/campaigns/import_json",
        content=json.dumps(exported),
        headers={"content-type": "application/json"},
    )
    assert resp2.status_code == HTTPStatus.OK
    # The response should contain the editor modal and prefilled data
    assert "campaign" in resp2.text or "editor" in resp2.text
    # Simulate round-trip: export → import → re-export (schema only)
    # (In a real UI, user would fill missing fields before saving)
    # Here, just ensure the template can be re-serialized/deserialized
    reloaded = CampaignTemplate.model_validate(template.model_dump())
    assert reloaded.name == template.name
    # Missing hash_list_id or resource GUIDs is expected and left for user to resolve
    # No DB persistence is required at this stage
