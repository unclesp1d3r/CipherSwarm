from datetime import UTC, datetime
from uuid import uuid4

import pytest
from httpx import AsyncClient

# from app.models.project import Project  # Unused import removed
from app.models.agent import Agent, AgentState
from app.models.attack import Attack, AttackMode, AttackState
from app.models.campaign import Campaign
from app.models.operating_system import OperatingSystem, OSName
from app.models.task import Task, TaskStatus


@pytest.mark.asyncio
async def test_campaign_progress_endpoint(
    async_client: AsyncClient, db_session, project_factory, caplog
):
    # Setup: create OS, project, campaign, agent, attack, and task
    os = OperatingSystem(id=uuid4(), name=OSName.linux, cracker_command="hashcat")
    db_session.add(os)
    await db_session.commit()
    await db_session.refresh(os)
    project = project_factory.build()
    db_session.add(project)
    await db_session.commit()
    campaign = Campaign(
        name="ProgressTest", description="Progress", project_id=project.id
    )
    db_session.add(campaign)
    await db_session.commit()
    await db_session.refresh(campaign)
    agent = Agent(
        host_name="progress-agent",
        client_signature="progress-sig",
        agent_type="physical",
        state=AgentState.active,
        token=f"csa_{uuid4()}_{uuid4().hex}",
        operating_system_id=os.id,
    )
    db_session.add(agent)
    await db_session.commit()
    await db_session.refresh(agent)
    attack = Attack(
        name="Progress Attack",
        description="Progress test attack",
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
        start_time=None,
        end_time=None,
        campaign_id=campaign.id,
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
        progress=50.0,
    )
    # If keyspace_total is needed, set it in error_details or another mapped field here
    # task.error_details = {"keyspace_total": 10000}
    db_session.add(task)
    await db_session.commit()
    await db_session.refresh(task)
    # Test endpoint
    with caplog.at_level("INFO"):
        resp = await async_client.get(f"/api/v1/web/campaigns/{campaign.id}/progress")
    assert resp.status_code == 200
    data = resp.json()
    print("Returned JSON:", data)
    print("Captured log output:\n", caplog.text)
    assert "active_agents" in data
    assert "total_tasks" in data
    assert data["active_agents"] == 1
    assert data["total_tasks"] == 1
    assert "Campaign progress calculated" in caplog.text
