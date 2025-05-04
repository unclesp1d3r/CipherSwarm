from datetime import UTC, datetime
from http import HTTPStatus
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent import Agent, AgentState, AgentType
from app.models.attack import Attack, AttackMode, AttackState
from app.models.hash_type import HashType
from app.models.operating_system import OperatingSystem, OSName


@pytest.mark.asyncio
async def test_attack_config_success(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Seed hash_types table before any dependent insert
    await db_session.execute(
        insert(HashType),
        [
            {"id": 0, "name": "MD5", "description": "MD5"},
            {"id": 100, "name": "SHA1", "description": "SHA1"},
        ],
    )
    await db_session.commit()
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
    # Add MD5 benchmark for agent
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
    # Create attack
    attack = Attack(
        name="Test Attack",
        description="Integration test attack",
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
        campaign_id=None,
        template_id=None,
    )
    db_session.add(attack)
    await db_session.commit()
    await db_session.refresh(attack)
    # Request config
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.get(
        f"/api/v1/attacks/{attack.id}/config", headers=headers
    )
    assert resp.status_code == HTTPStatus.OK
    data = resp.json()
    assert data["id"] == attack.id
    assert data["name"] == "Test Attack"


@pytest.mark.asyncio
async def test_attack_config_not_found(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Seed hash_types table before any dependent insert
    await db_session.execute(
        insert(HashType),
        [
            {"id": 0, "name": "MD5", "description": "MD5"},
            {"id": 100, "name": "SHA1", "description": "SHA1"},
        ],
    )
    await db_session.commit()
    # Create OS and agent with valid token
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-notfound",
        client_signature="test-sig-notfound",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    # Add MD5 benchmark for agent
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
    # Use valid token, but non-existent attack id
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.get("/api/v1/attacks/999999/config", headers=headers)
    assert resp.status_code == HTTPStatus.NOT_FOUND


@pytest.mark.asyncio
async def test_attack_config_invalid_token(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = {
        "Authorization": "Bearer invalidtoken",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.get("/api/v1/attacks/1/config", headers=headers)
    assert resp.status_code == HTTPStatus.UNAUTHORIZED


@pytest.mark.asyncio
async def test_attack_config_invalid_user_agent(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    headers = {
        "Authorization": "Bearer csa_fakeid_token",
        "User-Agent": "InvalidAgent/1.0.0",
    }
    resp = await async_client.get("/api/v1/attacks/1/config", headers=headers)
    assert resp.status_code == HTTPStatus.BAD_REQUEST


@pytest.mark.asyncio
async def test_attack_config_agent_incapable(
    async_client: AsyncClient, db_session: AsyncSession
) -> None:
    # Seed hash_types table before any dependent insert
    await db_session.execute(
        insert(HashType),
        [
            {"id": 0, "name": "MD5", "description": "MD5"},
            {"id": 100, "name": "SHA1", "description": "SHA1"},
        ],
    )
    await db_session.commit()
    # Create OS
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    # Create agent
    agent = Agent(
        id=uuid4(),
        host_name="test-agent-incapable",
        client_signature="test-sig-incapable",
        agent_type=AgentType.physical,
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    # Create attack with SHA1 (agent will only have MD5 benchmark)
    attack = Attack(
        name="Test Attack Incapable",
        description="Agent cannot handle this hash type",
        state=AttackState.PENDING,
        hash_type_id=100,
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
    # Add only MD5 benchmark for agent
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
    # Request config (should fail with 403)
    headers = {
        "Authorization": f"Bearer {agent.token}",
        "User-Agent": "CipherSwarm-Agent/1.0.0",
    }
    resp = await async_client.get(
        f"/api/v1/attacks/{attack.id}/config", headers=headers
    )
    assert resp.status_code == HTTPStatus.FORBIDDEN
    assert "does not support required hash type" in resp.text
