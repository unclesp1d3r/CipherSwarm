from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.responses import Response

from app.core.deps import get_db
from app.core.services.agent_service import get_agent_by_id_service, list_agents_service

router = APIRouter()
_templates = Jinja2Templates(directory="templates")


@router.get("/agents", summary="List/filter agents", tags=["Agents"])
async def list_agents_fragment(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    search: Annotated[str | None, Query(description="Search by host name")] = None,
    state: Annotated[str | None, Query(description="Filter by agent state")] = None,
    page: Annotated[int, Query(ge=1, description="Page number")] = 1,
    size: Annotated[int, Query(ge=1, le=100, description="Page size")] = 20,
) -> Response:
    """Return an HTML fragment with a paginated, filterable list of agents."""
    agents, total = await list_agents_service(db, search, state, page, size)
    return _templates.TemplateResponse(
        "agents/table_fragment.html.j2",
        {
            "request": request,
            "agents": agents,
            "page": page,
            "size": size,
            "total": total,
            "total_pages": (total + size - 1) // size if total else 1,
            "search": search,
            "state": state,
        },
    )


@router.get("/agents/{agent_id}", summary="Agent detail modal", tags=["Agents"])
async def agent_detail_modal(
    request: Request,
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    agent = await get_agent_by_id_service(agent_id, db)
    if not agent:
        raise HTTPException(status_code=404, detail="Agent not found")
    return _templates.TemplateResponse(
        "agents/details_modal.html.j2",
        {"request": request, "agent": agent},
    )
