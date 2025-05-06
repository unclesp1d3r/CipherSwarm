from uuid import uuid4

import pytest
from httpx import AsyncClient

from app.models.attack import AttackMode
from app.models.campaign import Campaign


@pytest.mark.asyncio
async def test_attach_attack_success(
    async_client: AsyncClient, db_session, project_factory, attack_factory
):
    # Create project, campaign, and attack
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    campaign = Campaign(name="AttachTest", description="Attach", project_id=project.id)
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    attack = attack_factory.build(
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="abc123",
        name="TestAttack",
        attack_mode=AttackMode.DICTIONARY,
        hash_type_id=0,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    # Attach
    resp = await async_client.post(
        f"/api/v1/web/campaigns/{campaign.id}/attacks/{attack.id}/attach"
    )
    if resp.status_code != 200:
        print(f"Attach failed: {resp.status_code} {resp.text}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == attack.id
    assert data["campaign_id"] == str(campaign.id)


@pytest.mark.asyncio
async def test_attach_attack_campaign_not_found(
    async_client: AsyncClient, db_session, attack_factory
):
    attack = attack_factory.build()
    db_session.add(attack)
    await db_session.commit()
    fake_campaign_id = str(uuid4())
    resp = await async_client.post(
        f"/api/v1/web/campaigns/{fake_campaign_id}/attacks/{attack.id}/attach"
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_attach_attack_attack_not_found(
    async_client: AsyncClient, db_session, project_factory
):
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    campaign = Campaign(
        name="AttachTest2", description="Attach2", project_id=project.id
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    fake_attack_id = 999999
    resp = await async_client.post(
        f"/api/v1/web/campaigns/{campaign.id}/attacks/{fake_attack_id}/attach"
    )
    assert resp.status_code == 404


@pytest.mark.asyncio
async def test_attach_attack_already_attached(
    async_client: AsyncClient, db_session, project_factory, attack_factory
):
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    campaign = Campaign(
        name="AttachTest3", description="Attach3", project_id=project.id
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    attack = attack_factory.build(campaign_id=campaign.id)
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    # Attach again (should succeed, idempotent)
    resp = await async_client.post(
        f"/api/v1/web/campaigns/{campaign.id}/attacks/{attack.id}/attach"
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == attack.id
    assert data["campaign_id"] == str(campaign.id)


@pytest.mark.asyncio
async def test_detach_attack_success(
    async_client: AsyncClient, db_session, project_factory, attack_factory
):
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    campaign = Campaign(name="DetachTest", description="Detach", project_id=project.id)
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    attack = attack_factory.build(campaign_id=campaign.id)
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    # Detach
    resp = await async_client.post(
        f"/api/v1/web/campaigns/{campaign.id}/attacks/{attack.id}/detach"
    )
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == attack.id
    assert data["campaign_id"] is None


@pytest.mark.asyncio
async def test_detach_attack_not_attached(
    async_client: AsyncClient, db_session, project_factory, attack_factory
):
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    campaign = Campaign(
        name="DetachTest2", description="Detach2", project_id=project.id
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    attack = attack_factory.build()
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    # Detach (should fail)
    resp = await async_client.post(
        f"/api/v1/web/campaigns/{campaign.id}/attacks/{attack.id}/detach"
    )
    assert resp.status_code == 400 or resp.status_code == 404


@pytest.mark.asyncio
async def test_detach_attack_invalid_ids(async_client: AsyncClient):
    fake_campaign_id = str(uuid4())
    fake_attack_id = 999999
    resp = await async_client.post(
        f"/api/v1/web/campaigns/{fake_campaign_id}/attacks/{fake_attack_id}/detach"
    )
    assert resp.status_code == 404
