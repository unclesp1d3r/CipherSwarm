from datetime import UTC, datetime
from http import HTTPStatus
from uuid import uuid4

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent import Agent, AgentState, AgentType
from app.models.attack import Attack, AttackMode, AttackState, HashType
from app.models.operating_system import OperatingSystem, OSName


@pytest.mark.asyncio
async def test_attack_config_success(
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
    headers = {
        "Authorization": "Bearer csa_fakeid_token",
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
