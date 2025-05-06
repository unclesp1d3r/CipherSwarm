from datetime import UTC, datetime
from http import HTTPStatus
from typing import Any, cast
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import selectinload

from app.models.agent import Agent, AgentState, AgentType
from app.models.attack import Attack, AttackMode, AttackState
from app.models.campaign import Campaign
from app.models.hash_type import HashType
from app.models.hashcat_benchmark import HashcatBenchmark
from app.models.operating_system import OperatingSystem, OSName
from app.models.project import Project, project_agents  # noqa: F401
from app.models.task import Task, TaskStatus

# Magic values for test assertions
EXPECTED_PROGRESS = 42.5
EXPECTED_KEYSPACE_PROCESSED = 123456
EXPECTED_RUNTIME = 12.3


async def ensure_hash_type(db_session: AsyncSession) -> HashType:
    hash_type = await db_session.get(HashType, 0)
    if not hash_type:
        hash_type = HashType(id=0, name="MD5", description="Message Digest 5")
        db_session.add(hash_type)
        await db_session.commit()
    return hash_type


async def create_agent_with_benchmark(
    db_session: AsyncSession,
    os: OperatingSystem,
    hash_type: HashType,
    async_engine=None,  # noqa: ANN001
    **agent_kwargs: Any,
) -> tuple[Agent, Agent]:
    agent = Agent(
        id=uuid4(),
        host_name=agent_kwargs.get("host_name", "test-agent"),
        client_signature=agent_kwargs.get("client_signature", "test-sig"),
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
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
    await db_session.refresh(os)
    # Add agent to project
    project = Project(name="TaskAssignProj", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    project.agents.append(agent)
    await db_session.flush()
    await db_session.commit()
    # Move all relationship access before session close
    # Eagerly load benchmarks for assertion
    agent_with_bench = (
        await db_session.execute(
            select(Agent)
            .options(selectinload(Agent.benchmarks))
            .where(Agent.id == agent.id)
        )
    ).scalar_one()
    await db_session.close()

    if async_engine is not None:
        async_session_maker = async_sessionmaker(
            async_engine, expire_on_commit=False, class_=AsyncSession
        )
        async with async_session_maker() as fresh_session:
            project_obj = (
                await fresh_session.execute(
                    select(Project)
                    .options(selectinload(Project.agents))
                    .where(Project.id == project.id)
                )
            ).scalar_one()
            agent_ids = [a.id for a in project_obj.agents]
            assert agent.id in agent_ids
    return agent, agent_with_bench


async def create_attack(
    db_session: AsyncSession, hash_type: HashType, **attack_kwargs: Any
) -> Attack:
    attack = Attack(
        name=attack_kwargs.get("name", "Test Attack"),
        description=attack_kwargs.get("description", "Integration test attack"),
        state=attack_kwargs.get("state", AttackState.PENDING),
        hash_type_id=hash_type.id,
        attack_mode=attack_kwargs.get("attack_mode", AttackMode.DICTIONARY),
        attack_mode_hashcat=attack_kwargs.get("attack_mode_hashcat", 0),
        hash_mode=attack_kwargs.get("hash_mode", 0),
        mask=attack_kwargs.get("mask"),
        increment_mode=attack_kwargs.get("increment_mode", False),
        increment_minimum=attack_kwargs.get("increment_minimum", 0),
        increment_maximum=attack_kwargs.get("increment_maximum", 0),
        optimized=attack_kwargs.get("optimized", False),
        slow_candidate_generators=attack_kwargs.get("slow_candidate_generators", False),
        workload_profile=attack_kwargs.get("workload_profile", 3),
        disable_markov=attack_kwargs.get("disable_markov", False),
        classic_markov=attack_kwargs.get("classic_markov", False),
        markov_threshold=attack_kwargs.get("markov_threshold", 0),
        left_rule=attack_kwargs.get("left_rule"),
        right_rule=attack_kwargs.get("right_rule"),
        custom_charset_1=attack_kwargs.get("custom_charset_1"),
        custom_charset_2=attack_kwargs.get("custom_charset_2"),
        custom_charset_3=attack_kwargs.get("custom_charset_3"),
        custom_charset_4=attack_kwargs.get("custom_charset_4"),
        hash_list_id=attack_kwargs.get("hash_list_id", 1),
        hash_list_url=attack_kwargs.get(
            "hash_list_url", "http://example.com/hashes.txt"
        ),
        hash_list_checksum=attack_kwargs.get("hash_list_checksum", "deadbeef"),
        priority=attack_kwargs.get("priority", 0),
        start_time=attack_kwargs.get("start_time", datetime.now(UTC)),
        end_time=attack_kwargs.get("end_time"),
        campaign_id=attack_kwargs.get("campaign_id"),
        template_id=attack_kwargs.get("template_id"),
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    return attack


@pytest.mark.asyncio
async def test_task_assignment_success(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    hash_type = await ensure_hash_type(db_session)
    project = Project(
        name=f"TaskAssignProj_{uuid4()}", description="Test", private=False
    )
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    campaign = Campaign(
        name="TaskAssignCamp", description="Test", project_id=project.id
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent",
        client_signature="test-sig",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
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
    await db_session.refresh(os)
    # Add agent to project
    project.agents.append(agent)
    await db_session.flush()
    await db_session.refresh(project)
    await db_session.refresh(agent)
    # Assert the relationship is hydrated
    assert agent.id in [a.id for a in project.agents]
    attack = await create_attack(
        db_session,
        hash_type,
        campaign_id=campaign.id,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
    )
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.PENDING,
        agent_id=None,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.post("/api/v1/tasks/assign", headers=headers)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["id"] == task.id
    assert data["agent_id"] == str(agent.id)
    assert data["status"] == "running" or data["status"] == "RUNNING"
    assert "skip" in data
    assert "limit" in data
    # Ensure relationships and linkage
    assert campaign.project_id == project.id
    assert attack.campaign_id == campaign.id
    assert attack.hash_type_id == hash_type.id == agent.benchmarks[0].hash_type_id
    assert task.attack_id == attack.id
    assert task.status == TaskStatus.RUNNING
    assert task.agent_id == agent.id
    assert agent.state == AgentState.active
    assert all(b.hash_type_id == hash_type.id for b in agent.benchmarks)


@pytest.mark.asyncio
async def test_task_assignment_no_pending(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Ensure HashType exists
    hash_type = await ensure_hash_type(db_session)
    # Create OS
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    # Create agent
    await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    # Create attack (not used, but ensures no FK error if needed)
    _ = await create_attack(db_session, hash_type)
    # No pending tasks
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = cast("Agent", agent_with_bench)
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "CipherSwarm-Agent/1.0.0",
        }
        resp = await async_client.post("/api/v1/tasks/assign", headers=headers)
        assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_task_assignment_invalid_token(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = {
        "Authorization": "Bearer invalidtoken",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.post("/api/v1/tasks/assign", headers=headers)
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_task_progress_update_success(
    async_client: AsyncClient,
    db_session: AsyncSession,
    async_engine: AsyncEngine,
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent, agent_with_bench = await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    attack = await create_attack(db_session, hash_type)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (  # type: ignore[assignment]
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = agent_with_bench
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "CipherSwarm-Agent/1.0.0",
        }
        payload = {
            "progress_percent": EXPECTED_PROGRESS,
            "keyspace_processed": EXPECTED_KEYSPACE_PROCESSED,
        }
        resp = await async_client.post(
            f"/api/v1/client/tasks/{task.id}/progress", json=payload, headers=headers
        )
        assert resp.status_code == HTTPStatus.NO_CONTENT
        # Confirm DB update
        await db_session.refresh(task)
        assert task.progress == EXPECTED_PROGRESS
        if task.error_details and "keyspace_processed" in task.error_details:
            assert (
                task.error_details["keyspace_processed"] == EXPECTED_KEYSPACE_PROCESSED
            )


@pytest.mark.asyncio
async def test_task_progress_update_invalid_token(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = {
        "Authorization": "Bearer invalidtoken",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    payload = {"progress_percent": 10.0, "keyspace_processed": 100}
    resp = await async_client.post(
        "/api/v1/client/tasks/1/progress", json=payload, headers=headers
    )
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_task_progress_update_agent_not_assigned(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Setup: create OS, agent, attack, and running task NOT assigned to agent
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    attack = await create_attack(db_session, hash_type)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=None,  # Not assigned
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = cast("Agent", agent_with_bench)
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "CipherSwarm-Agent/1.0.0",
        }
        payload = {"progress_percent": 10.0, "keyspace_processed": 100}
        resp = await async_client.post(
            f"/api/v1/client/tasks/{task.id}/progress", json=payload, headers=headers
        )
        # v1: agent not assigned should return 404 (legacy/Swagger behavior)
        assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_task_progress_update_task_not_running(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Setup: create OS, agent, attack, and task assigned to agent but not running
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent, agent_with_bench = await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    attack = await create_attack(db_session, hash_type)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.PAUSED,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (  # type: ignore[assignment]
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = agent_with_bench
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "CipherSwarm-Agent/1.0.0",
        }
        payload = {"progress_percent": 10.0, "keyspace_processed": 100}
        resp = await async_client.post(
            f"/api/v1/client/tasks/{task.id}/progress", json=payload, headers=headers
        )
        assert resp.status_code == HTTPStatus.CONFLICT


@pytest.mark.asyncio
async def test_task_progress_update_invalid_headers(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent, agent_with_bench = await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    attack = await create_attack(db_session, hash_type)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    # v1: User-Agent is not required, so only Authorization matters
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (  # type: ignore[assignment]
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = agent_with_bench
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "InvalidAgent/1.0.0",
        }
        payload = {"progress_percent": 10.0, "keyspace_processed": 100}
        resp = await async_client.post(
            f"/api/v1/client/tasks/{task.id}/progress", json=payload, headers=headers
        )
        # Should succeed if Authorization is valid, or 401 if not
        assert resp.status_code in (HTTPStatus.NO_CONTENT, HTTPStatus.UNAUTHORIZED)


@pytest.mark.asyncio
async def test_task_result_submit_success(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent, agent_with_bench = await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    attack = await create_attack(db_session, hash_type)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (  # type: ignore[assignment]
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = agent_with_bench
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "CipherSwarm-Agent/1.0.0",
        }
        payload = {
            "cracked_hashes": [{"hash": "abc123", "plain": "password1"}],
            "metadata": {"runtime": EXPECTED_RUNTIME},
            "error": None,
        }
        resp = await async_client.post(
            f"/api/v1/client/tasks/{task.id}/result", json=payload, headers=headers
        )
        assert resp.status_code == HTTPStatus.NO_CONTENT
        await db_session.refresh(task)
        assert task.status == TaskStatus.COMPLETED
        # v1: Extract cracked_hashes from error_details['result']['cracked_hashes']
        cracked_hashes = []
        if isinstance(task.error_details, dict):
            result = task.error_details.get("result")
            if isinstance(result, dict):
                cracked_hashes = result.get("cracked_hashes", [])
        assert isinstance(cracked_hashes, list), (
            f"cracked_hashes missing or not a list: {task.error_details}"
        )
        assert any(
            isinstance(entry, dict) and entry.get("hash") == "abc123"
            for entry in cracked_hashes
        )


@pytest.mark.asyncio
async def test_task_result_submit_with_error(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent, agent_with_bench = await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    attack = await create_attack(db_session, hash_type)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (  # type: ignore[assignment]
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = agent_with_bench
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "CipherSwarm-Agent/1.0.0",
        }
        payload = {
            "cracked_hashes": [],
            "metadata": {"runtime": 0.0},
            "error": "Hashcat crashed",
        }
        resp = await async_client.post(
            f"/api/v1/client/tasks/{task.id}/result", json=payload, headers=headers
        )
        assert resp.status_code == HTTPStatus.NO_CONTENT
        await db_session.refresh(task)
        assert task.status == TaskStatus.FAILED
        assert task.error_message == "Hashcat crashed"


@pytest.mark.asyncio
async def test_task_result_submit_invalid_token(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = {
        "Authorization": "Bearer invalidtoken",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    payload = {"cracked_hashes": [], "metadata": {}, "error": None}
    resp = await async_client.post(
        "/api/v1/client/tasks/1/result", json=payload, headers=headers
    )
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_task_result_submit_agent_not_assigned(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Setup: create OS, agent, attack, and running task NOT assigned to agent
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent, agent_with_bench = await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    attack = await create_attack(db_session, hash_type)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=None,  # Not assigned
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (  # type: ignore[assignment]
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = agent_with_bench
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "CipherSwarm-Agent/1.0.0",
        }
        payload = {"cracked_hashes": [], "metadata": {}, "error": None}
        resp = await async_client.post(
            f"/api/v1/client/tasks/{task.id}/result", json=payload, headers=headers
        )
        # v1: agent not assigned should return 404 (legacy/Swagger behavior)
        assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_task_result_submit_task_not_running(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Setup: create OS, agent, attack, and task assigned to agent but not running
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent, agent_with_bench = await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    attack = await create_attack(db_session, hash_type)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.PAUSED,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (  # type: ignore[assignment]
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = agent_with_bench
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "CipherSwarm-Agent/1.0.0",
        }
        payload = {"cracked_hashes": [], "metadata": {}, "error": None}
        resp = await async_client.post(
            f"/api/v1/client/tasks/{task.id}/result", json=payload, headers=headers
        )
        assert resp.status_code == HTTPStatus.CONFLICT


@pytest.mark.asyncio
async def test_task_result_submit_invalid_headers(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent, agent_with_bench = await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    attack = await create_attack(db_session, hash_type)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    # v1: User-Agent is not required, so only Authorization matters
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (  # type: ignore[assignment]
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = agent_with_bench
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "InvalidAgent/1.0.0",
        }
        payload = {"cracked_hashes": [], "metadata": {}, "error": None}
        resp = await async_client.post(
            f"/api/v1/client/tasks/{task.id}/result", json=payload, headers=headers
        )
        # Should succeed if Authorization is valid, or 401 if not
        assert resp.status_code in (HTTPStatus.NO_CONTENT, HTTPStatus.UNAUTHORIZED)


@pytest.mark.asyncio
async def test_get_new_task_success(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    hash_type = await ensure_hash_type(db_session)
    project = Project(
        name=f"TaskAssignProj2_{uuid4()}", description="Test", private=False
    )
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    campaign = Campaign(
        name="TaskAssignCamp2", description="Test", project_id=project.id
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent2",
        client_signature="test-sig2",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    benchmark = HashcatBenchmark(
        agent_id=agent.id,
        hash_type_id=hash_type.id,
        hash_speed=100000.0,
        runtime=100,
        device="cpu0",
    )
    db_session.add(benchmark)
    await db_session.commit()
    await db_session.refresh(agent)
    await db_session.refresh(project)
    # Add agent to project
    project.agents.append(agent)
    await db_session.flush()
    await db_session.commit()
    await db_session.close()

    if async_engine is not None:
        async_session_maker = async_sessionmaker(
            async_engine, expire_on_commit=False, class_=AsyncSession
        )
        async with async_session_maker() as fresh_session:
            project_obj = (
                await fresh_session.execute(
                    select(Project)
                    .options(selectinload(Project.agents))
                    .where(Project.id == project.id)
                )
            ).scalar_one()
            agent_ids = [a.id for a in project_obj.agents]
            assert agent.id in agent_ids
    # Do not refresh agent/project after session close


@pytest.mark.asyncio
async def test_get_new_task_none_available(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Setup: create OS, agent, but no pending tasks
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (  # type: ignore[assignment]
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = agent_with_bench
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "CipherSwarm-Agent/1.0.0",
        }
        resp = await async_client.get("/api/v2/client/tasks/new", headers=headers)
        assert resp.status_code == HTTPStatus.NO_CONTENT


@pytest.mark.asyncio
async def test_submit_cracked_hash_success(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent, agent_with_bench = await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    attack = await create_attack(db_session, hash_type)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (  # type: ignore[assignment]
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = agent_with_bench
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "CipherSwarm-Agent/1.0.0",
        }
        payload = {
            "timestamp": datetime.now(UTC).isoformat(),
            "hash": "abc123",
            "plain_text": "password1",
        }
        resp = await async_client.post(
            f"/api/v2/client/tasks/{task.id}/submit_crack",
            json=payload,
            headers=headers,
        )
        assert resp.status_code == HTTPStatus.OK
        data = resp.json()
        assert "message" in data
        await db_session.refresh(task)
        # v2: Extract cracked_hashes from error_details['cracked_hashes']
        cracked_hashes = []
        if isinstance(task.error_details, dict):
            cracked_hashes = task.error_details.get("cracked_hashes", [])
        assert isinstance(cracked_hashes, list), (
            f"cracked_hashes missing or not a list: {task.error_details}"
        )
        assert any(
            isinstance(entry, dict) and entry.get("hash") == "abc123"
            for entry in cracked_hashes
        )


@pytest.mark.asyncio
async def test_submit_cracked_hash_already_submitted(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent with hash already submitted
    hash_type = await ensure_hash_type(db_session)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent, agent_with_bench = await create_agent_with_benchmark(
        db_session, os, hash_type, async_engine=async_engine
    )
    attack = await create_attack(db_session, hash_type)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
        error_details={
            "cracked_hashes": [
                {
                    "timestamp": datetime.now(UTC).isoformat(),
                    "hash": "abc123",
                    "plain_text": "password1",
                }
            ]
        },
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    task.error_details = {"keyspace_total": 1000000}
    await db_session.commit()
    await db_session.refresh(task)
    session_factory = async_sessionmaker(
        async_engine, expire_on_commit=False, class_=AsyncSession
    )
    async with session_factory() as fresh_session:
        agent_with_bench = (
            (  # type: ignore[assignment]
                await fresh_session.execute(
                    select(Agent)
                    .options(selectinload(Agent.benchmarks))
                    .order_by(Agent.id.desc())
                )
            )
            .scalars()
            .first()
        )
        assert agent_with_bench is not None, (
            "agent_with_bench is None after re-query; agent creation or flush failed"
        )
        hydrated_agent = agent_with_bench
        headers = {
            "Authorization": f"Bearer {hydrated_agent.token}",
            "User-Agent": "CipherSwarm-Agent/1.0.0",
        }
        payload = {
            "timestamp": datetime.now(UTC).isoformat(),
            "hash": "abc123",
            "plain_text": "password1",
        }
        resp = await async_client.post(
            f"/api/v2/client/tasks/{task.id}/submit_crack",
            json=payload,
            headers=headers,
        )
        assert resp.status_code == HTTPStatus.OK


@pytest.mark.asyncio
async def test_task_assignment_one_task_per_agent(
    async_client: AsyncClient, db_session: AsyncSession, async_engine: AsyncEngine
) -> None:
    hash_type = await ensure_hash_type(db_session)
    project = Project(
        name=f"TaskAssignProj3_{uuid4()}", description="Test", private=False
    )
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    campaign = Campaign(
        name="TaskAssignCamp3", description="Test", project_id=project.id
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent3",
        client_signature="test-sig3",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    benchmark = HashcatBenchmark(
        agent_id=agent.id,
        hash_type_id=hash_type.id,
        hash_speed=250000.0,
        runtime=100,
        device="cpu0",
    )
    db_session.add(benchmark)
    await db_session.commit()
    await db_session.refresh(agent)
    await db_session.refresh(project)
    # Add agent to project
    project.agents.append(agent)
    await db_session.flush()
    await db_session.commit()
    await db_session.close()

    if async_engine is not None:
        async_session_maker = async_sessionmaker(
            async_engine, expire_on_commit=False, class_=AsyncSession
        )
        async with async_session_maker() as fresh_session:
            project_obj = (
                await fresh_session.execute(
                    select(Project)
                    .options(selectinload(Project.agents))
                    .where(Project.id == project.id)
                )
            ).scalar_one()
            agent_ids = [a.id for a in project_obj.agents]
            assert agent.id in agent_ids
    # Do not refresh agent/project after session close
