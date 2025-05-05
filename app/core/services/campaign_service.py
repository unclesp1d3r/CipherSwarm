from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.attack_complexity_service import calculate_attack_complexity
from app.models.agent import Agent, AgentState
from app.models.attack import Attack
from app.models.campaign import Campaign
from app.models.task import Task, TaskStatus
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
    return [CampaignRead.model_validate(c) for c in campaigns]


async def get_campaign_service(campaign_id: UUID, db: AsyncSession) -> CampaignRead:
    result = await db.execute(select(Campaign).where(Campaign.id == campaign_id))
    campaign = result.scalar_one_or_none()
    if not campaign:
        raise CampaignNotFoundError(f"Campaign {campaign_id} not found")
    return CampaignRead.model_validate(campaign)


async def create_campaign_service(
    data: CampaignCreate, db: AsyncSession
) -> CampaignRead:
    campaign = Campaign(
        name=data.name,
        description=data.description,
        project_id=data.project_id,
    )
    db.add(campaign)
    await db.commit()
    await db.refresh(campaign)
    return CampaignRead.model_validate(campaign)


async def update_campaign_service(
    campaign_id: UUID, data: CampaignUpdate, db: AsyncSession
) -> CampaignRead:
    result = await db.execute(select(Campaign).where(Campaign.id == campaign_id))
    campaign = result.scalar_one_or_none()
    if not campaign:
        raise CampaignNotFoundError(f"Campaign {campaign_id} not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(campaign, field, value)
    await db.commit()
    await db.refresh(campaign)
    return CampaignRead.model_validate(campaign)


async def delete_campaign_service(campaign_id: UUID, db: AsyncSession) -> None:
    result = await db.execute(select(Campaign).where(Campaign.id == campaign_id))
    campaign = result.scalar_one_or_none()
    if not campaign:
        raise CampaignNotFoundError(f"Campaign {campaign_id} not found")
    await db.delete(campaign)
    await db.commit()


async def attach_attack_to_campaign_service(
    campaign_id: UUID, attack_id: int, db: AsyncSession
) -> AttackOut:
    # Find campaign
    result = await db.execute(select(Campaign).where(Campaign.id == campaign_id))
    campaign = result.scalar_one_or_none()
    if not campaign:
        raise CampaignNotFoundError(f"Campaign {campaign_id} not found")
    # Find attack
    result = await db.execute(select(Attack).where(Attack.id == attack_id))
    attack = result.scalar_one_or_none()
    if not attack:
        raise AttackNotFoundError(f"Attack {attack_id} not found")
    # Attach
    attack.campaign_id = campaign_id
    await db.commit()
    await db.refresh(attack)
    # --- Post-attach: re-sort attacks by complexity (ascending) ---
    # Fetch all attacks for this campaign
    result = await db.execute(select(Attack).where(Attack.campaign_id == campaign.id))
    attacks = result.scalars().all()
    # Calculate complexity for each attack
    attack_complexities = [(a, calculate_attack_complexity(a)) for a in attacks]
    # Sort attacks in ascending order of complexity
    attack_complexities.sort(key=lambda x: x[1])
    # If a sort_order field exists, persist it; otherwise, sort in memory only
    for idx, (a, _) in enumerate(attack_complexities):
        if hasattr(a, "sort_order"):
            a.sort_order = idx  # type: ignore[attr-defined]
        # else: in-memory sort only; no persistent order
    await db.commit()
    # --- End re-sort ---
    return AttackOut.model_validate(attack)


async def detach_attack_from_campaign_service(
    campaign_id: UUID, attack_id: int, db: AsyncSession
) -> AttackOut:
    # Find campaign
    result = await db.execute(select(Campaign).where(Campaign.id == campaign_id))
    campaign = result.scalar_one_or_none()
    if not campaign:
        raise CampaignNotFoundError(f"Campaign {campaign_id} not found")
    # Find attack
    result = await db.execute(select(Attack).where(Attack.id == attack_id))
    attack = result.scalar_one_or_none()
    if not attack:
        raise AttackNotFoundError(f"Attack {attack_id} not found")
    # Detach only if currently attached to this campaign
    if attack.campaign_id != campaign_id:
        raise ValueError(
            f"Attack {attack_id} is not attached to campaign {campaign_id}"
        )
    attack.campaign_id = None
    await db.commit()
    await db.refresh(attack)
    return AttackOut.model_validate(attack)


async def get_campaign_progress_service(
    campaign_id: UUID, db: AsyncSession
) -> CampaignProgress:
    # Get all attacks for the campaign
    result = await db.execute(
        select(Attack.id).where(Attack.campaign_id == campaign_id)
    )
    attack_ids = [row[0] for row in result.all()]
    if not attack_ids:
        return CampaignProgress(active_agents=0, total_tasks=0)
    # Count total tasks for these attacks
    result = await db.execute(
        select(func.count(Task.id)).where(Task.attack_id.in_(attack_ids))
    )
    total_tasks = result.scalar_one() or 0
    # Find unique agent_ids assigned to these tasks
    result = await db.execute(
        select(Task.agent_id).where(
            Task.attack_id.in_(attack_ids), Task.agent_id.isnot(None)
        )
    )
    agent_ids = {row[0] for row in result.all()}
    if not agent_ids:
        return CampaignProgress(active_agents=0, total_tasks=total_tasks)
    # Count agents in 'active' state
    result = await db.execute(
        select(func.count(Agent.id)).where(
            Agent.id.in_(agent_ids), Agent.state == AgentState.active
        )
    )
    active_agents = result.scalar_one() or 0
    return CampaignProgress(active_agents=active_agents, total_tasks=total_tasks)


# --- Task retry stub ---
def mark_task_for_retry(task: Task) -> None:
    """Mark a task for retry: set to pending and increment retry_count."""
    task.status = TaskStatus.PENDING
    if hasattr(task, "retry_count") and task.retry_count is not None:
        task.retry_count += 1
    else:
        task.retry_count = 1
