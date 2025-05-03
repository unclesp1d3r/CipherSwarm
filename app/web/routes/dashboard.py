from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.models.agent import Agent, AgentState
from app.models.hashcat_result import HashcatResult
from app.models.task import Task, TaskStatus

router = APIRouter()

# Initialize templates
templates = Jinja2Templates(directory="templates")


@router.get("/", response_class=HTMLResponse)
async def dashboard(
    request: Request,
    db: AsyncSession = Depends(get_db),
):
    """Dashboard view with system statistics."""
    # Get active agents count and change
    active_agents_query = (
        select(func.count()).select_from(Agent).where(Agent.state == AgentState.ACTIVE)
    )
    active_agents = await db.scalar(active_agents_query) or 0

    # Calculate active agents change (last 24h)
    yesterday = datetime.utcnow() - timedelta(days=1)
    active_agents_yesterday_query = (
        select(func.count())
        .select_from(Agent)
        .where(Agent.state == AgentState.ACTIVE, Agent.created_at <= yesterday)
    )
    active_agents_yesterday = await db.scalar(active_agents_yesterday_query) or 0
    active_agents_change = active_agents - active_agents_yesterday

    # Get running tasks count
    running_tasks_query = (
        select(func.count()).select_from(Task).where(Task.status == TaskStatus.RUNNING)
    )
    running_tasks = await db.scalar(running_tasks_query) or 0

    # Get cracked hashes in last 24h
    cracked_hashes_query = (
        select(func.count())
        .select_from(HashcatResult)
        .where(HashcatResult.timestamp >= yesterday)
    )
    cracked_hashes_24h = await db.scalar(cracked_hashes_query) or 0

    # Calculate cracked hashes change
    two_days_ago = datetime.utcnow() - timedelta(days=2)
    cracked_hashes_previous_query = (
        select(func.count())
        .select_from(HashcatResult)
        .where(HashcatResult.timestamp.between(two_days_ago, yesterday))
    )
    cracked_hashes_previous = (
        await db.scalar(cracked_hashes_previous_query) or 1
    )  # Avoid division by zero
    cracked_hashes_change = (
        (cracked_hashes_24h - cracked_hashes_previous) / cracked_hashes_previous
    ) * 100

    # Calculate resource usage (percentage of active agents with tasks)
    agents_with_tasks_query = (
        select(func.count(Agent.id))
        .select_from(Agent)
        .join(Task, Task.agent_id == Agent.id)
        .where(Agent.state == AgentState.ACTIVE, Task.status == TaskStatus.RUNNING)
    )
    agents_with_tasks = await db.scalar(agents_with_tasks_query) or 0
    resource_usage = (
        (agents_with_tasks / active_agents * 100) if active_agents > 0 else 0
    )

    # Get recent events
    recent_events: list[dict] = []

    # Get recent task status changes
    tasks_query = select(Task).order_by(Task.updated_at.desc()).limit(5)
    tasks_result = await db.execute(tasks_query)
    tasks = tasks_result.scalars().all()

    for task in tasks:
        recent_events.append(
            {
                "timestamp": task.updated_at,
                "event": f"Task {task.id} {task.status}",
                "details": (
                    f"Agent {task.agent_id}" if task.agent_id else "No agent assigned"
                ),
            }
        )

    # Get recent agent status changes
    agents_query = select(Agent).order_by(Agent.updated_at.desc()).limit(5)
    agents_result = await db.execute(agents_query)
    agents = agents_result.scalars().all()

    for agent in agents:
        recent_events.append(
            {
                "timestamp": agent.updated_at,
                "event": f"Agent {agent.host_name} {agent.state}",
                "details": (
                    f"Last seen: {agent.last_seen_at}"
                    if agent.last_seen_at
                    else "Never seen"
                ),
            }
        )

    # Sort events by timestamp
    recent_events.sort(key=lambda x: x["timestamp"], reverse=True)
    recent_events = recent_events[:5]  # Keep only 5 most recent events

    # Get active tasks with details
    active_tasks_query = (
        select(Task)
        .join(Agent)
        .where(Task.status == TaskStatus.RUNNING)
        .order_by(Task.start_date.desc())
    )
    active_tasks_result = await db.execute(active_tasks_query)
    active_tasks = active_tasks_result.scalars().all()

    active_tasks_data = []
    for task in active_tasks:
        active_tasks_data.append(
            {
                "name": f"Task {task.id}",
                "agent": f"Agent {task.agent_id}" if task.agent_id else "No agent",
                "progress": task.progress or 0,
                "eta": (
                    task.estimated_completion.strftime("%Y-%m-%d %H:%M:%S")
                    if task.estimated_completion
                    else "Unknown"
                ),
            }
        )

    return templates.TemplateResponse(
        "dashboard.html",
        {
            "request": request,
            "active_agents": active_agents,
            "active_agents_change": (
                f"+{active_agents_change}"
                if active_agents_change > 0
                else active_agents_change
            ),
            "running_tasks": running_tasks,
            "cracked_hashes_24h": cracked_hashes_24h,
            "cracked_hashes_change": round(cracked_hashes_change, 1),
            "resource_usage": round(resource_usage, 1),
            "recent_events": recent_events,
            "active_tasks": active_tasks_data,
        },
    )
