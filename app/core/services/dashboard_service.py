from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.agent import Agent
from app.models.agent_device_performance import AgentDevicePerformance
from app.models.crack_result import CrackResult
from app.models.task import Task, TaskStatus
from app.schemas.shared import DashboardSummary, ResourceUsagePoint


async def get_dashboard_summary_service(db: AsyncSession) -> DashboardSummary:
    now = datetime.now(UTC)
    online_cutoff = now - timedelta(minutes=2)

    total_agents = await db.scalar(select(func.count()).select_from(Agent))
    active_agents = await db.scalar(
        select(func.count())
        .select_from(Agent)
        .where(Agent.last_seen_at >= online_cutoff, Agent.enabled)
    )

    running_tasks = await db.scalar(
        select(func.count()).select_from(Task).where(Task.status == TaskStatus.RUNNING)
    )
    total_tasks = await db.scalar(select(func.count()).select_from(Task))

    since = now - timedelta(hours=24)
    recently_cracked_hashes = await db.scalar(
        select(func.count())
        .select_from(CrackResult)
        .where(CrackResult.created_at >= since)
    )

    # Resource usage sparkline: sum of all agent/device speeds per hour for last 12 hours
    resource_usage: list[ResourceUsagePoint] = []
    for i in range(11, -1, -1):
        bucket_start = (now - timedelta(hours=i)).replace(
            minute=0, second=0, microsecond=0
        )
        bucket_end = bucket_start + timedelta(hours=1)
        result = await db.execute(
            select(func.sum(AgentDevicePerformance.speed))
            .where(AgentDevicePerformance.timestamp >= bucket_start)
            .where(AgentDevicePerformance.timestamp < bucket_end)
        )
        hash_rate = result.scalar() or 0.0
        resource_usage.append(
            ResourceUsagePoint(timestamp=bucket_start, hash_rate=hash_rate)
        )

    return DashboardSummary(
        active_agents=active_agents or 0,
        total_agents=total_agents or 0,
        running_tasks=running_tasks or 0,
        total_tasks=total_tasks or 0,
        recently_cracked_hashes=recently_cracked_hashes or 0,
        resource_usage=resource_usage,
    )
