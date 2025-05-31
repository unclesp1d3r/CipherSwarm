# ... moved code from test_task_assignment.py ...

from datetime import UTC, datetime
from uuid import uuid4

import pytest
from httpx import AsyncClient, codes
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession

from app.models.agent import Agent, AgentState, AgentType, OperatingSystemEnum
from app.models.attack import Attack, AttackMode, AttackState
from app.models.campaign import Campaign
from app.models.hash_type import HashType
from app.models.hashcat_benchmark import HashcatBenchmark
from app.models.project import Project
from app.models.task import Task, TaskStatus
from tests.factories.hash_item_factory import HashItemFactory
from tests.factories.hash_list_factory import HashListFactory


# --- Helper functions (copied from test_task_assignment.py) ---
async def ensure_hash_type(db_session: AsyncSession) -> HashType:
    hash_type = await db_session.get(HashType, 0)
    if not hash_type:
        hash_type = HashType(id=0, name="MD5", description="Message Digest 5")
        db_session.add(hash_type)
        await db_session.commit()
    return hash_type


async def create_agent_with_benchmark(
    db_session: AsyncSession,
    os: OperatingSystemEnum,
    hash_type: HashType,
    async_engine=None,  # noqa: ANN001
    **agent_kwargs,  # noqa: ANN003
) -> tuple[Agent, Agent]:
    agent = Agent(
        host_name=agent_kwargs.get(
            "host_name", f"test-agent-{datetime.now(UTC).timestamp()}"
        ),
        client_signature=agent_kwargs.get(
            "client_signature", f"test-sig-{datetime.now(UTC).timestamp()}"
        ),
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{datetime.now(UTC).timestamp()}_testtoken",
        operating_system=os,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    benchmark = HashcatBenchmark(
        agent_id=agent.id,
        hash_type_id=hash_type.id,
        hash_speed=500000.0,
        runtime=100,
        device="cpu0",
    )
    db_session.add(benchmark)
    await db_session.commit()
    await db_session.refresh(agent)
    project = Project(name=f"Test Project {uuid4()}", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    project.agents.append(agent)
    await db_session.flush()
    await db_session.commit()
    return agent, agent


async def create_attack(
    db_session: AsyncSession,
    **attack_kwargs,  # noqa: ANN003
) -> Attack:
    if "campaign_id" not in attack_kwargs or attack_kwargs["campaign_id"] is None:
        raise ValueError("campaign_id is required for create_attack")
    attack = Attack(
        name=attack_kwargs.get("name", "Test Attack"),
        description=attack_kwargs.get("description", "Integration test attack"),
        state=attack_kwargs.get("state", AttackState.PENDING),
        attack_mode=attack_kwargs.get("attack_mode", AttackMode.DICTIONARY),
        attack_mode_hashcat=attack_kwargs.get("attack_mode_hashcat", 0),
        hash_mode=attack_kwargs.get("hash_mode", 0),
        campaign_id=attack_kwargs["campaign_id"],
        hash_list_id=attack_kwargs.get("hash_list_id", 1),
        hash_list_url=attack_kwargs.get(
            "hash_list_url", "http://example.com/hashes.txt"
        ),
        hash_list_checksum=attack_kwargs.get("hash_list_checksum", "deadbeef"),
        priority=attack_kwargs.get("priority", 0),
        start_time=attack_kwargs.get("start_time", datetime.now(UTC)),
        end_time=attack_kwargs.get("end_time"),
        template_id=attack_kwargs.get("template_id"),
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    return attack


# --- /submit_crack endpoint tests ---
@pytest.mark.asyncio
async def test_submit_cracked_hash_success(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    project = Project(name=f"Test Project {uuid4()}", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    hash_list = HashListFactory.build(project_id=project.id, hash_type_id=0)
    hash_item = HashItemFactory.build(hash="abc123", plain_text=None)
    hash_list.items.append(hash_item)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    campaign = Campaign(
        name="Test Campaign",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent, _ = await create_agent_with_benchmark(
        db_session,
        OperatingSystemEnum.linux,
        await ensure_hash_type(db_session),
        async_engine=async_engine,
    )
    attack = await create_attack(
        db_session,
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
    )
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    await db_session.refresh(hash_item)
    headers = {"Authorization": f"Bearer {agent.token}"}
    payload = {
        "hash": "abc123",
        "plain_text": "password1",
        "timestamp": datetime.now(UTC).isoformat(),
    }
    resp = await async_client.post(
        f"/api/v1/client/tasks/{task.id}/submit_crack", json=payload, headers=headers
    )
    assert resp.status_code == codes.OK
    data = resp.json()
    assert data["message"] == "Cracked hash submitted"
    await db_session.refresh(hash_item)
    assert hash_item.plain_text == "password1"
    from app.models.crack_result import CrackResult

    result = await db_session.execute(
        select(CrackResult).filter(CrackResult.hash_item_id == hash_item.id)
    )
    crack_result = result.scalar_one_or_none()
    assert crack_result is not None
    assert crack_result.agent_id == agent.id
    assert crack_result.attack_id == attack.id


@pytest.mark.asyncio
async def test_submit_cracked_hash_invalid_token(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    project = Project(name=f"Test Project {uuid4()}", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    hash_list = HashListFactory.build(project_id=project.id, hash_type_id=0)
    hash_item = HashItemFactory.build(hash="abc123", plain_text=None)
    hash_list.items.append(hash_item)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    campaign = Campaign(
        name="Test Campaign",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent, _ = await create_agent_with_benchmark(
        db_session,
        OperatingSystemEnum.linux,
        await ensure_hash_type(db_session),
        async_engine=async_engine,
    )
    attack = await create_attack(
        db_session,
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
    )
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {"Authorization": "Bearer invalidtoken"}
    payload = {
        "hash": "abc123",
        "plain_text": "password1",
        "timestamp": datetime.now(UTC).isoformat(),
    }
    resp = await async_client.post(
        f"/api/v1/client/tasks/{task.id}/submit_crack", json=payload, headers=headers
    )
    assert resp.status_code == codes.UNAUTHORIZED
    assert resp.json()["error"] == "Not authorized"


@pytest.mark.asyncio
async def test_submit_cracked_hash_agent_not_assigned(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    project = Project(name=f"Test Project {uuid4()}", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    hash_list = HashListFactory.build(project_id=project.id, hash_type_id=0)
    hash_item = HashItemFactory.build(hash="abc123", plain_text=None)
    hash_list.items.append(hash_item)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    campaign = Campaign(
        name="Test Campaign",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent1, _ = await create_agent_with_benchmark(
        db_session,
        OperatingSystemEnum.linux,
        await ensure_hash_type(db_session),
        async_engine=async_engine,
    )
    agent2, _ = await create_agent_with_benchmark(
        db_session,
        OperatingSystemEnum.macos,
        await ensure_hash_type(db_session),
        async_engine=async_engine,
        host_name="other-agent",
        client_signature="sig2",
    )
    attack = await create_attack(
        db_session,
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
    )
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent1.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {"Authorization": f"Bearer {agent2.token}"}
    payload = {
        "hash": "abc123",
        "plain_text": "password1",
        "timestamp": datetime.now(UTC).isoformat(),
    }
    resp = await async_client.post(
        f"/api/v1/client/tasks/{task.id}/submit_crack", json=payload, headers=headers
    )
    assert resp.status_code == codes.NOT_FOUND
    assert resp.json()["error"] == "Record not found"


@pytest.mark.asyncio
async def test_submit_cracked_hash_task_not_running(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    project = Project(name=f"Test Project {uuid4()}", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    hash_list = HashListFactory.build(project_id=project.id, hash_type_id=0)
    hash_item = HashItemFactory.build(hash="abc123", plain_text=None)
    hash_list.items.append(hash_item)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    campaign = Campaign(
        name="Test Campaign",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent, _ = await create_agent_with_benchmark(
        db_session,
        OperatingSystemEnum.linux,
        await ensure_hash_type(db_session),
        async_engine=async_engine,
    )
    attack = await create_attack(
        db_session,
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
    )
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.PAUSED,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {"Authorization": f"Bearer {agent.token}"}
    payload = {
        "hash": "abc123",
        "plain_text": "password1",
        "timestamp": datetime.now(UTC).isoformat(),
    }
    resp = await async_client.post(
        f"/api/v1/client/tasks/{task.id}/submit_crack", json=payload, headers=headers
    )
    assert resp.status_code == codes.CONFLICT
    assert resp.json()["error"] == "Task not running"


@pytest.mark.asyncio
async def test_submit_cracked_hash_hash_not_found(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    project = Project(name=f"Test Project {uuid4()}", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    hash_list = HashListFactory.build(project_id=project.id, hash_type_id=0)
    hash_item = HashItemFactory.build(hash="abc123", plain_text=None)
    hash_list.items.append(hash_item)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    campaign = Campaign(
        name="Test Campaign",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent, _ = await create_agent_with_benchmark(
        db_session,
        OperatingSystemEnum.linux,
        await ensure_hash_type(db_session),
        async_engine=async_engine,
    )
    attack = await create_attack(
        db_session,
        campaign_id=campaign.id,
        hash_list_id=hash_list.id,
    )
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {"Authorization": f"Bearer {agent.token}"}
    payload = {
        "hash": "not_in_list",
        "plain_text": "password1",
        "timestamp": datetime.now(UTC).isoformat(),
    }
    resp = await async_client.post(
        f"/api/v1/client/tasks/{task.id}/submit_crack", json=payload, headers=headers
    )
    assert resp.status_code == codes.UNPROCESSABLE_ENTITY
    assert resp.json()["error"] == "Hash not found in hash list"
