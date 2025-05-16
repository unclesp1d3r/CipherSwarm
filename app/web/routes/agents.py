from typing import Annotated, Any

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.models.agent import Agent
from app.web.templates import jinja

router = APIRouter()


@router.get("/agents")
@jinja.page("agents/list.html.j2")
async def list_agents(
    db: Annotated[AsyncSession, Depends(get_db)],
    search: str | None = None,
    state: str | None = None,
) -> dict[str, Any]:
    """List agents with optional filtering."""
    query = select(Agent)

    if search:
        query = query.filter(Agent.host_name.ilike(f"%{search}%"))

    if state:
        query = query.filter(Agent.state == state)

    result = await db.execute(query)
    agents = result.scalars().all()

    return {
        "agents": agents,
    }


@router.get("/agents/{id}/details")
@jinja.hx("agents/details_modal.html.j2")
async def agent_details(
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, Any]:
    """Show agent details in a modal."""
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()

    return {
        "agent": agent,
    }


@router.get("/agents/register")
@jinja.hx("agents/register_modal.html.j2")
async def register_agent_modal() -> dict[str, Any]:
    """Return the agent registration modal as an HTML fragment for HTMX."""
    return {}
