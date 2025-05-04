from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.models.agent import Agent

router = APIRouter()

# Initialize templates
templates = Jinja2Templates(directory="templates")


@router.get("/agents", response_class=HTMLResponse)
async def list_agents(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    search: str | None = None,
    state: str | None = None,
) -> HTMLResponse:
    """List agents with optional filtering."""
    query = select(Agent)

    if search:
        query = query.filter(Agent.host_name.ilike(f"%{search}%"))

    if state:
        query = query.filter(Agent.state == state)

    result = await db.execute(query)
    agents = result.scalars().all()

    return templates.TemplateResponse(
        "agents/list.html",
        {
            "request": request,
            "agents": agents,
        },
    )


@router.get("/agents/{id}/details", response_class=HTMLResponse)
async def agent_details(
    request: Request,
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> HTMLResponse:
    """Show agent details in a modal."""
    result = await db.execute(select(Agent).filter(Agent.id == agent_id))
    agent = result.scalar_one_or_none()

    return templates.TemplateResponse(
        "agents/details_modal.html",
        {
            "request": request,
            "agent": agent,
        },
    )
