from collections.abc import Sequence

from fastapi import HTTPException
from loguru import logger
from sqlalchemy import Result, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.attack_complexity_service import calculate_attack_complexity
from app.models.agent import Agent, AgentState
from app.models.attack import Attack
from app.models.campaign import Campaign
from app.models.task import Task, TaskStatus
from app.models.user import User
from app.schemas.attack import AttackOut
from app.schemas.campaign import (
    CampaignCreate,
    CampaignProgress,
    CampaignRead,
    CampaignUpdate,
)


class CampaignNotFoundError(Exception):
    pass


class AttackNotFoundError(Exception):
    pass


async def list_campaigns_service(db: AsyncSession) -> list[CampaignRead]:
    result = await db.execute(select(Campaign))
    campaigns = result.scalars().all()
    return [CampaignRead.model_validate(c, from_attributes=True) for c in campaigns]


async def get_campaign_service(campaign_id: int, db: AsyncSession) -> CampaignRead:
    result = await db.execute(select(Campaign).where(Campaign.id == campaign_id))
    campaign = result.scalar_one_or_none()
    if not campaign:
        raise CampaignNotFoundError(f"Campaign {campaign_id} not found")
    return CampaignRead.model_validate(campaign, from_attributes=True)


async def create_campaign_service(
    data: CampaignCreate, db: AsyncSession
) -> CampaignRead:
    logger.debug(f"Entering create_campaign_service with data: {data}")
    campaign = Campaign(
        name=data.name,
        description=data.description,
        project_id=data.project_id,
        priority=data.priority,
        hash_list_id=data.hash_list_id,
    )
    db.add(campaign)
    await db.commit()
    await db.refresh(campaign)
    logger.info(f"Campaign created: {data.name}")
    logger.debug("Exiting create_campaign_service")
    return CampaignRead.model_validate(campaign, from_attributes=True)


async def update_campaign_service(
    campaign_id: int, data: CampaignUpdate, db: AsyncSession
) -> CampaignRead:
    result = await db.execute(select(Campaign).where(Campaign.id == campaign_id))
    campaign = result.scalar_one_or_none()
    if not campaign:
        raise CampaignNotFoundError(f"Campaign {campaign_id} not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(campaign, field, value)
    await db.commit()
    await db.refresh(campaign)
    return CampaignRead.model_validate(campaign, from_attributes=True)


async def delete_campaign_service(campaign_id: int, db: AsyncSession) -> None:
    result = await db.execute(select(Campaign).where(Campaign.id == campaign_id))
    campaign = result.scalar_one_or_none()
    if not campaign:
        raise CampaignNotFoundError(f"Campaign {campaign_id} not found")
    await db.delete(campaign)
    await db.commit()


async def attach_attack_to_campaign_service(
    campaign_id: int, attack_id: int, db: AsyncSession
) -> AttackOut:
    # Find campaign
    campaign_result: Result[tuple[Campaign]] = await db.execute(
        select(Campaign).where(Campaign.id == campaign_id)
    )
    campaign = campaign_result.scalar_one_or_none()
    if not campaign:
        raise CampaignNotFoundError(f"Campaign {campaign_id} not found")
    # Find attack
    attack_result: Result[tuple[Attack]] = await db.execute(
        select(Attack).where(Attack.id == attack_id)
    )
    attack = attack_result.scalar_one_or_none()
    if not attack:
        raise AttackNotFoundError(f"Attack {attack_id} not found")

    attack.campaign_id = campaign_id
    await db.commit()
    await db.refresh(attack)
    # --- Post-attach: re-sort attacks by complexity (ascending) ---
    # Fetch all attacks for this campaign
    attack_results: Result[tuple[Attack]] = await db.execute(
        select(Attack).where(Attack.campaign_id == campaign.id)
    )
    attacks: Sequence[Attack] = attack_results.scalars().all()
    # Calculate complexity for each attack
    attack_complexities: list[tuple[Attack, int]] = [
        (a, calculate_attack_complexity(a)) for a in attacks
    ]
    # Sort attacks in ascending order of complexity
    attack_complexities.sort(key=lambda x: x[1])
    # No-op: sort_order not present on Attack; skip assignment
    await db.commit()
    # --- End re-sort ---
    return AttackOut.model_validate(attack, from_attributes=True)


async def detach_attack_from_campaign_service(
    campaign_id: int, attack_id: int, db: AsyncSession
) -> dict[str, bool | int]:
    # Find campaign
    campaign_result: Result[tuple[Campaign]] = await db.execute(
        select(Campaign).where(Campaign.id == campaign_id)
    )
    campaign = campaign_result.scalar_one_or_none()
    if not campaign:
        raise CampaignNotFoundError(f"Campaign {campaign_id} not found")
    # Find attack
    attack_result: Result[tuple[Attack]] = await db.execute(
        select(Attack).where(Attack.id == attack_id)
    )
    attack = attack_result.scalar_one_or_none()
    if not attack:
        raise AttackNotFoundError(f"Attack {attack_id} not found")
    # Only allow delete if currently attached to this campaign
    if attack.campaign_id != campaign_id:
        raise ValueError(
            f"Attack {attack_id} is not attached to campaign {campaign_id}"
        )
    await db.delete(attack)
    await db.commit()
    return {"id": attack_id, "deleted": True}


async def get_campaign_progress_service(
    campaign_id: int, db: AsyncSession
) -> CampaignProgress:
    # Get all attacks for the campaign
    result_ids: Result[tuple[int]] = await db.execute(
        select(Attack.id).where(Attack.campaign_id == campaign_id)
    )
    attack_ids: Sequence[int] = result_ids.scalars().all()
    if not attack_ids:
        return CampaignProgress(active_agents=0, total_tasks=0)
    # Count total tasks for these attacks
    count_result: Result[tuple[int]] = await db.execute(
        select(func.count(Task.id)).where(Task.attack_id.in_(attack_ids))
    )
    total_tasks = count_result.scalar_one() or 0
    # Find unique agent_ids assigned to these tasks
    agent_ids_result: Result[tuple[int | None]] = await db.execute(
        select(Task.agent_id).where(
            Task.attack_id.in_(attack_ids), Task.agent_id.isnot(None)
        )
    )
    agent_ids: set[int | None] = {row[0] for row in agent_ids_result.all()}
    if not agent_ids:
        return CampaignProgress(active_agents=0, total_tasks=total_tasks)
    # Count agents in 'active' state
    agent_count_result: Result[tuple[int]] = await db.execute(
        select(func.count(Agent.id)).where(
            Agent.id.in_(agent_ids), Agent.state == AgentState.active
        )
    )
    active_agents = agent_count_result.scalar_one() or 0
    logger.info(
        f"Campaign progress calculated for campaign_id={campaign_id}: active_agents={active_agents}, total_tasks={total_tasks}"
    )
    return CampaignProgress(active_agents=active_agents, total_tasks=total_tasks)


# --- Task retry stub ---
def mark_task_for_retry(task: Task) -> None:
    """Mark a task for retry: set to pending and increment retry_count."""
    task.status = TaskStatus.PENDING
    if hasattr(task, "retry_count") and task.retry_count is not None:
        task.retry_count += 1
    else:
        task.retry_count = 1


async def raise_campaign_priority_service(
    campaign_id: int, _user: User, db: AsyncSession
) -> CampaignRead:
    result = await db.execute(select(Campaign).where(Campaign.id == campaign_id))
    campaign = result.scalar_one_or_none()
    if not campaign:
        raise HTTPException(status_code=404, detail="Campaign not found")
    campaign.priority += 1
    await db.commit()
    await db.refresh(campaign)
    return CampaignRead.model_validate(campaign, from_attributes=True)
