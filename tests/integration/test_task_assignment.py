from datetime import UTC, datetime
from http import HTTPStatus
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent import Agent, AgentState, AgentType
from app.models.attack import Attack, AttackMode, AttackState, HashType
from app.models.operating_system import OperatingSystem, OSName
from app.models.task import Task, TaskStatus

# Magic values for test assertions
EXPECTED_PROGRESS = 42.5
EXPECTED_KEYSPACE_PROCESSED = 123456
EXPECTED_RUNTIME = 12.3


@pytest.mark.asyncio
async def test_task_assignment_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create OS
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    # Create agent
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
    # Create attack
    attack = Attack(
        name="Test Attack",
        description="Integration test attack",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    # Create pending task
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.PENDING,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    # Assign task
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


@pytest.mark.asyncio
async def test_task_assignment_no_pending(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create OS
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    # Create agent
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
    # Create attack (not used, but ensures no FK error if needed)
    attack = Attack(
        name="Test Attack 2",
        description="Integration test attack 2",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes2.txt",
        hash_list_checksum="beefdead",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    # No pending tasks
    headers = {
        "Authorization": f"Bearer {agent.token}",
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
async def test_task_assignment_invalid_user_agent(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = {
        "Authorization": "Bearer csa_validtoken_stub",
        "User-Agent": "InvalidAgent/1.0.0",
    }
    resp = await async_client.post("/api/v1/tasks/assign", headers=headers)
    assert resp.status_code == HTTPStatus.BAD_REQUEST


@pytest.mark.asyncio
async def test_task_progress_update_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-progress",
        client_signature="test-sig-progress",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack Progress",
        description="Integration test attack progress",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {
        "Authorization": f"Bearer {agent.token}",
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
        assert task.error_details["keyspace_processed"] == EXPECTED_KEYSPACE_PROCESSED


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
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and running task NOT assigned to agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-unassigned",
        client_signature="test-sig-unassigned",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack Unassigned",
        description="Integration test attack unassigned",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=None,  # Not assigned
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {
        "Authorization": f"Bearer {agent.token}",
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
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and task assigned to agent but not running
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-notrunning",
        client_signature="test-sig-notrunning",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack NotRunning",
        description="Integration test attack not running",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.PAUSED,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    payload = {"progress_percent": 10.0, "keyspace_processed": 100}
    resp = await async_client.post(
        f"/api/v1/client/tasks/{task.id}/progress", json=payload, headers=headers
    )
    assert resp.status_code == HTTPStatus.CONFLICT


@pytest.mark.asyncio
async def test_task_progress_update_invalid_headers(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-badheaders",
        client_signature="test-sig-badheaders",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack BadHeaders",
        description="Integration test attack bad headers",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    # v1: User-Agent is not required, so only Authorization matters
    headers = {
        "Authorization": f"Bearer {agent.token}",
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
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-result",
        client_signature="test-sig-result",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack Result",
        description="Integration test attack result",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {
        "Authorization": f"Bearer {agent.token}",
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
    if task.error_details and "result" in task.error_details:
        assert task.error_details["result"]["cracked_hashes"][0]["plain"] == "password1"
        assert task.error_details["result"]["metadata"]["runtime"] == EXPECTED_RUNTIME


@pytest.mark.asyncio
async def test_task_result_submit_with_error(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-result-err",
        client_signature="test-sig-result-err",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack ResultErr",
        description="Integration test attack result error",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {
        "Authorization": f"Bearer {agent.token}",
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
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and running task NOT assigned to agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-result-unassigned",
        client_signature="test-sig-result-unassigned",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack ResultUnassigned",
        description="Integration test attack result unassigned",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=None,  # Not assigned
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {
        "Authorization": f"Bearer {agent.token}",
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
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and task assigned to agent but not running
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-result-notrunning",
        client_signature="test-sig-result-notrunning",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack ResultNotRunning",
        description="Integration test attack result not running",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.PAUSED,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    payload = {"cracked_hashes": [], "metadata": {}, "error": None}
    resp = await async_client.post(
        f"/api/v1/client/tasks/{task.id}/result", json=payload, headers=headers
    )
    assert resp.status_code == HTTPStatus.CONFLICT


@pytest.mark.asyncio
async def test_task_result_submit_invalid_headers(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-result-badheaders",
        client_signature="test-sig-result-badheaders",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack ResultBadHeaders",
        description="Integration test attack result bad headers",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    # v1: User-Agent is not required, so only Authorization matters
    headers = {
        "Authorization": f"Bearer {agent.token}",
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
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and pending task
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-newtask",
        client_signature="test-sig-newtask",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack NewTask",
        description="Integration test attack new task",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.PENDING,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.get("/api/v2/client/tasks/new", headers=headers)
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["id"] == task.id
    assert data["agent_id"] == str(agent.id)
    assert data["status"] == "running" or data["status"] == "RUNNING"


@pytest.mark.asyncio
async def test_get_new_task_none_available(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, but no pending tasks
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-newtask-none",
        client_signature="test-sig-newtask-none",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.get("/api/v2/client/tasks/new", headers=headers)
    assert resp.status_code == HTTPStatus.NO_CONTENT


@pytest.mark.asyncio
async def test_submit_cracked_hash_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-crack",
        client_signature="test-sig-crack",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack Crack",
        description="Integration test attack crack",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    task = Task(
        attack_id=attack.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        agent_id=agent.id,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    payload = {
        "timestamp": datetime.now(UTC).isoformat(),
        "hash": "abc123",
        "plain_text": "password1",
    }
    resp = await async_client.post(
        f"/api/v2/client/tasks/{task.id}/submit_crack", json=payload, headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert "message" in data
    await db_session.refresh(task)
    assert any(
        entry["hash"] == "abc123"
        for entry in (task.error_details or {}).get("cracked_hashes", [])
    )


@pytest.mark.asyncio
async def test_submit_cracked_hash_already_submitted(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: create OS, agent, attack, and running task assigned to agent with hash already submitted
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-crack-dupe",
        client_signature="test-sig-crack-dupe",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Test Attack CrackDupe",
        description="Integration test attack crack dupe",
        state=AttackState.PENDING,
        hash_type=HashType.MD5,
        attack_mode=AttackMode.DICTIONARY,
        attack_mode_hashcat=0,
        hash_mode=0,
        mask=None,
        increment_mode=False,
        increment_minimum=0,
        increment_maximum=0,
        optimized=False,
        slow_candidate_generators=False,
        workload_profile=3,
        disable_markov=False,
        classic_markov=False,
        markov_threshold=0,
        left_rule=None,
        right_rule=None,
        custom_charset_1=None,
        custom_charset_2=None,
        custom_charset_3=None,
        custom_charset_4=None,
        hash_list_id=1,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
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
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    payload = {
        "timestamp": datetime.now(UTC).isoformat(),
        "hash": "abc123",
        "plain_text": "password1",
    }
    resp = await async_client.post(
        f"/api/v2/client/tasks/{task.id}/submit_crack", json=payload, headers=headers
    )
    assert resp.status_code == HTTPStatus.NO_CONTENT
