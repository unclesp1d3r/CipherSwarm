from datetime import UTC, datetime
from http import HTTPStatus

import pytest
from httpx import AsyncClient, codes
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent import Agent, AgentState, AgentType
from app.models.attack import Attack, AttackMode, AttackState
from app.models.campaign import Campaign
from app.models.operating_system import OperatingSystem, OSName
from app.models.project import Project
from tests.factories.hash_item_factory import HashItemFactory
from tests.factories.hash_list_factory import HashListFactory


@pytest.mark.asyncio
async def test_attack_v1_agent_api_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup identical to test_attack_config_success
    os = OperatingSystem(id=2, name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    project = Project(name="Test Project 2", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    # Create a HashList and at least one HashItem
    hash_list = HashListFactory.build(project_id=project.id)
    hash_item = HashItemFactory.build()
    hash_list.items.append(hash_item)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    campaign = Campaign(
        name="Test Campaign 2",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent = Agent(
        id=2,
        host_name="test-agent-v1",
        client_signature="test-sig-v1",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{2}_testtoken",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    from app.models.hashcat_benchmark import HashcatBenchmark

    db_session.add(
        HashcatBenchmark(
            agent_id=agent.id,
            hash_type_id=0,
            runtime=100,
            hash_speed=1000.0,
            device="GPU0",
        )
    )
    await db_session.commit()
    attack = Attack(
        name="Test Attack V1",
        description="Integration test attack v1",
        state=AttackState.PENDING,
        hash_type_id=0,
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
        campaign_id=campaign.id,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.get(
        f"/api/v1/client/attacks/{attack.id}", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["id"] == attack.id
    assert "word_list" in data
    assert data["word_list"] is None
    assert "rule_list" in data
    assert data["rule_list"] is None
    assert "mask_list" in data
    assert data["mask_list"] is None


@pytest.mark.asyncio
async def test_attack_v1_agent_api_unauthorized(async_client: AsyncClient) -> None:
    resp = await async_client.get(
        "/api/v1/client/attacks/1", headers={"Authorization": "Bearer invalidtoken"}
    )
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_attack_v1_agent_api_not_found(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup valid agent
    os = OperatingSystem(id=3, name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=3,
        host_name="test-agent-v1-notfound",
        client_signature="test-sig-v1-notfound",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{3}_testtoken",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    from app.models.hashcat_benchmark import HashcatBenchmark

    db_session.add(
        HashcatBenchmark(
            agent_id=agent.id,
            hash_type_id=0,
            runtime=100,
            hash_speed=1000.0,
            device="GPU0",
        )
    )
    await db_session.commit()
    headers = {"Authorization": f"Bearer {agent.token}"}
    resp = await async_client.get("/api/v1/client/attacks/999999", headers=headers)
    assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_attack_v1_hash_list_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    from app.models.agent import Agent, AgentState, AgentType
    from app.models.attack import Attack, AttackMode, AttackState
    from app.models.campaign import Campaign
    from app.models.hash_item import HashItem
    from app.models.operating_system import OperatingSystem, OSName
    from app.models.project import Project

    os = OperatingSystem(id=10, name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    project = Project(name="HashList Project", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    # Explicitly create and persist HashItem objects with known values
    hash_items = [HashItem(hash=f"hash{i}") for i in range(3)]
    for item in hash_items:
        db_session.add(item)
    await db_session.flush()
    # Create HashList and attach items
    from app.models.hash_list import HashList

    hash_list = HashList(name="Test List", project_id=project.id)
    hash_list.items.extend(hash_items)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    campaign = Campaign(
        name="HashList Campaign",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent = Agent(
        id=10,
        host_name="hashlist-agent",
        client_signature="sig-hashlist",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{10}_testtoken",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    from app.models.hashcat_benchmark import HashcatBenchmark

    db_session.add(
        HashcatBenchmark(
            agent_id=agent.id,
            hash_type_id=0,
            runtime=100,
            hash_speed=1000.0,
            device="GPU0",
        )
    )
    await db_session.commit()
    attack = Attack(
        name="HashList Attack",
        description="Test attack for hash list endpoint",
        state=AttackState.PENDING,
        hash_type_id=0,
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
        hash_list_id=hash_list.id,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=campaign.id,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.get(
        f"/api/v1/client/attacks/{attack.id}/hash_list", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    assert resp.headers["content-type"].startswith("text/plain")
    lines = resp.text.strip().split("\n")
    assert set(lines) == {"hash0", "hash1", "hash2"}


@pytest.mark.asyncio
async def test_attack_v1_hash_list_unauthorized(async_client: AsyncClient) -> None:
    resp = await async_client.get(
        "/api/v1/client/attacks/1/hash_list",
        headers={"Authorization": "Bearer invalidtoken"},
    )
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_attack_v1_hash_list_not_found(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup valid agent
    from app.models.agent import Agent, AgentState, AgentType
    from app.models.operating_system import OperatingSystem, OSName

    os = OperatingSystem(id=11, name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=11,
        host_name="notfound-agent",
        client_signature="sig-notfound",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{11}_testtoken",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.get(
        "/api/v1/client/attacks/999999/hash_list", headers=headers
    )
    assert resp.status_code == codes.NOT_FOUND


@pytest.mark.asyncio
async def test_task_v1_get_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: OS, project, campaign, hash list, agent, attack, task
    os = OperatingSystem(id=20, name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    project = Project(name="Task Project", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    hash_list = HashListFactory.build(project_id=project.id)
    hash_item = HashItemFactory.build()
    hash_list.items.append(hash_item)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    campaign = Campaign(
        name="Task Campaign",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent = Agent(
        id=20,
        host_name="task-agent",
        client_signature="sig-task",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{20}_tok",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    from app.models.hashcat_benchmark import HashcatBenchmark

    db_session.add(
        HashcatBenchmark(
            agent_id=agent.id,
            hash_type_id=0,
            runtime=100,
            hash_speed=1000.0,
            device="GPU0",
        )
    )
    await db_session.commit()
    attack = Attack(
        name="Task Attack",
        description="Task test",
        state=AttackState.PENDING,
        hash_type_id=0,
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
        hash_list_id=hash_list.id,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=campaign.id,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    from app.models.task import Task, TaskStatus

    task = Task(
        attack_id=attack.id,
        agent_id=agent.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.PENDING,
        skip=0,
        limit=0,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {"Authorization": f"Bearer {agent.token}"}
    resp = await async_client.get(f"/api/v1/client/tasks/{task.id}", headers=headers)
    assert resp.status_code == codes.OK
    data = resp.json()
    assert data["id"] == task.id
    assert data["attack_id"] == attack.id
    assert data["status"] == "pending"


@pytest.mark.asyncio
async def test_task_v1_get_unauthorized(async_client: AsyncClient) -> None:
    resp = await async_client.get(
        "/api/v1/client/tasks/1", headers={"Authorization": "Bearer invalidtoken"}
    )
    assert resp.status_code == codes.UNAUTHORIZED


@pytest.mark.asyncio
async def test_task_v1_get_not_found(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup valid agent
    os = OperatingSystem(id=21, name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    agent = Agent(
        id=21,
        host_name="notfound-agent",
        client_signature="sig-notfound",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{21}_tok",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    headers = {"Authorization": f"Bearer {agent.token}"}
    resp = await async_client.get("/api/v1/client/tasks/999999", headers=headers)
    assert resp.status_code == codes.NOT_FOUND


@pytest.mark.asyncio
async def test_task_v1_get_forbidden(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: two agents, one assigned to task, one not
    os = OperatingSystem(id=22, name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    project = Project(name="Forbidden Project", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    hash_list = HashListFactory.build(project_id=project.id)
    hash_item = HashItemFactory.build()
    hash_list.items.append(hash_item)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    campaign = Campaign(
        name="Forbidden Campaign",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent1 = Agent(
        id=22,
        host_name="forbidden-agent1",
        client_signature="sig-forbidden1",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{22}_tok",
        operating_system_id=os.id,
    )
    agent2 = Agent(
        id=23,
        host_name="forbidden-agent2",
        client_signature="sig-forbidden2",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{23}_tok",
        operating_system_id=os.id,
    )
    db_session.add_all([agent1, agent2])
    await db_session.commit()
    await db_session.refresh(agent1)
    await db_session.refresh(agent2)
    from app.models.hashcat_benchmark import HashcatBenchmark

    db_session.add(
        HashcatBenchmark(
            agent_id=agent1.id,
            hash_type_id=0,
            runtime=100,
            hash_speed=1000.0,
            device="GPU0",
        )
    )
    db_session.add(
        HashcatBenchmark(
            agent_id=agent2.id,
            hash_type_id=0,
            runtime=100,
            hash_speed=1000.0,
            device="GPU0",
        )
    )
    await db_session.commit()
    attack = Attack(
        name="Forbidden Attack",
        description="Forbidden test",
        state=AttackState.PENDING,
        hash_type_id=0,
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
        hash_list_id=hash_list.id,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=campaign.id,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    from app.models.task import Task, TaskStatus

    task = Task(
        attack_id=attack.id,
        agent_id=agent1.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.PENDING,
        skip=0,
        limit=0,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {"Authorization": f"Bearer {agent2.token}"}
    resp = await async_client.get(f"/api/v1/client/tasks/{task.id}", headers=headers)
    assert resp.status_code == codes.FORBIDDEN


@pytest.mark.asyncio
async def test_task_v1_submit_status_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: OS, project, campaign, hash list, agent, attack, task
    os = OperatingSystem(id=30, name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    project = Project(name="Status Project", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    hash_list = HashListFactory.build(project_id=project.id)
    hash_item = HashItemFactory.build()
    hash_list.items.append(hash_item)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    campaign = Campaign(
        name="Status Campaign",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent = Agent(
        id=30,
        host_name="status-agent",
        client_signature="sig-status",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{30}_tok",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    from app.models.hashcat_benchmark import HashcatBenchmark

    db_session.add(
        HashcatBenchmark(
            agent_id=agent.id,
            hash_type_id=0,
            runtime=100,
            hash_speed=1000.0,
            device="GPU0",
        )
    )
    await db_session.commit()
    attack = Attack(
        name="Status Attack",
        description="Status test",
        state=AttackState.PENDING,
        hash_type_id=0,
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
        hash_list_id=hash_list.id,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=campaign.id,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    from app.models.task import Task, TaskStatus

    task = Task(
        attack_id=attack.id,
        agent_id=agent.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        skip=0,
        limit=0,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {"Authorization": f"Bearer {agent.token}"}
    payload = {"progress_percent": 50.0, "keyspace_processed": 1000}
    resp = await async_client.post(
        f"/api/v1/client/tasks/{task.id}/submit_status", json=payload, headers=headers
    )
    assert resp.status_code == codes.NO_CONTENT


@pytest.mark.asyncio
async def test_task_v1_submit_status_unauthorized(async_client: AsyncClient) -> None:
    payload = {"progress_percent": 10.0, "keyspace_processed": 100}
    resp = await async_client.post(
        "/api/v1/client/tasks/1/submit_status",
        json=payload,
        headers={"Authorization": "Bearer invalidtoken"},
    )
    assert resp.status_code == codes.UNAUTHORIZED


@pytest.mark.asyncio
async def test_task_v1_submit_status_not_found(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    os = OperatingSystem(id=31, name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    agent = Agent(
        id=31,
        host_name="notfound-status-agent",
        client_signature="sig-notfound-status",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{31}_tok",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    headers = {"Authorization": f"Bearer {agent.token}"}
    payload = {"progress_percent": 10.0, "keyspace_processed": 100}
    resp = await async_client.post(
        "/api/v1/client/tasks/999999/submit_status", json=payload, headers=headers
    )
    assert resp.status_code == codes.NOT_FOUND


@pytest.mark.asyncio
async def test_task_v1_submit_status_unprocessable(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    os = OperatingSystem(id=32, name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    agent = Agent(
        id=32,
        host_name="unprocessable-status-agent",
        client_signature="sig-unprocessable-status",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{32}_tok",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    headers = {"Authorization": f"Bearer {agent.token}"}
    # Malformed: missing keyspace_processed
    payload = {"progress_percent": 10.0}
    resp = await async_client.post(
        "/api/v1/client/tasks/1/submit_status", json=payload, headers=headers
    )
    assert resp.status_code in (codes.UNPROCESSABLE_ENTITY, codes.UNPROCESSABLE_ENTITY)


@pytest.mark.asyncio
async def test_task_v1_submit_status_forbidden(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Setup: two agents, one assigned to task, one not
    os = OperatingSystem(id=33, name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    project = Project(
        name="Forbidden Status Project", description="Test", private=False
    )
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    hash_list = HashListFactory.build(project_id=project.id)
    hash_item = HashItemFactory.build()
    hash_list.items.append(hash_item)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    campaign = Campaign(
        name="Forbidden Status Campaign",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent1 = Agent(
        id=33,
        host_name="forbidden-status-agent1",
        client_signature="sig-forbidden-status1",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{33}_tok",
        operating_system_id=os.id,
    )
    agent2 = Agent(
        id=34,
        host_name="forbidden-status-agent2",
        client_signature="sig-forbidden-status2",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{34}_tok",
        operating_system_id=os.id,
    )
    db_session.add_all([agent1, agent2])
    await db_session.commit()
    await db_session.refresh(agent1)
    await db_session.refresh(agent2)
    from app.models.hashcat_benchmark import HashcatBenchmark

    db_session.add(
        HashcatBenchmark(
            agent_id=agent1.id,
            hash_type_id=0,
            runtime=100,
            hash_speed=1000.0,
            device="GPU0",
        )
    )
    db_session.add(
        HashcatBenchmark(
            agent_id=agent2.id,
            hash_type_id=0,
            runtime=100,
            hash_speed=1000.0,
            device="GPU0",
        )
    )
    await db_session.commit()
    attack = Attack(
        name="Forbidden Status Attack",
        description="Forbidden status test",
        state=AttackState.PENDING,
        hash_type_id=0,
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
        hash_list_id=hash_list.id,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=campaign.id,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    from app.models.task import Task, TaskStatus

    task = Task(
        attack_id=attack.id,
        agent_id=agent1.id,
        start_date=datetime.now(UTC),
        status=TaskStatus.RUNNING,
        skip=0,
        limit=0,
    )
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    headers = {"Authorization": f"Bearer {agent2.token}"}
    payload = {"progress_percent": 10.0, "keyspace_processed": 100}
    resp = await async_client.post(
        f"/api/v1/client/tasks/{task.id}/submit_status", json=payload, headers=headers
    )
    assert resp.status_code == codes.FORBIDDEN


@pytest.mark.asyncio
async def test_duplicate_attack_endpoint(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Create a project
    project = Project(name="Duplicate Test Project", description="Test", private=False)
    db_session.add(project)
    await db_session.commit()
    await db_session.refresh(project)
    # Create a hash list
    hash_list = HashListFactory.build(project_id=project.id)
    db_session.add(hash_list)
    await db_session.flush()
    await db_session.commit()
    # Create a campaign
    campaign = Campaign(
        name="Duplicate Test Campaign",
        description="Test",
        project_id=project.id,
        hash_list_id=hash_list.id,
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    # Create an attack
    attack = Attack(
        name="Duplicate Test Attack",
        description="Test attack for duplicate endpoint",
        state=AttackState.PENDING,
        hash_type_id=0,
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
        hash_list_id=hash_list.id,
        hash_list_url="http://example.com/hashes.txt",
        hash_list_checksum="deadbeef",
        priority=0,
        start_time=datetime.now(UTC),
        end_time=None,
        campaign_id=campaign.id,
        template_id=None,
        position=0,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    # Duplicate the attack
    resp = await async_client.post(f"/api/v1/web/attacks/{attack.id}/duplicate")
    assert resp.status_code == HTTPStatus.CREATED
    data = resp.json()
    assert data["id"] != attack.id
    assert data["campaign_id"] == campaign.id
    assert data["name"].startswith(attack.name)
    assert data["position"] == 1  # Should be at the end
    # Check that the clone is in the DB
    clone = await db_session.get(Attack, data["id"])
    assert clone is not None
    assert clone.template_id == attack.id
    assert clone.state == "pending"
