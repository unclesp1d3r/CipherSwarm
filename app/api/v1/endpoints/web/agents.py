from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.responses import Response

from app.core.deps import get_current_user, get_db
from app.core.exceptions import AgentNotFoundError
from app.core.services.agent_service import (
    get_agent_benchmark_summary_service,
    get_agent_by_id_service,
    list_agents_service,
    toggle_agent_enabled_service,
    trigger_agent_benchmark_service,
)
from app.models.user import User
from app.web.templates import jinja

router = APIRouter(prefix="/agents", tags=["Agents"])

# NOTE: Stop adding Database code in the endpoints. Follow the service layer pattern.

# NOTE: user_can() is available and implemented, so stop adding TODO items and just implement the damn code.


@router.get("", summary="List/filter agents")
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
    return jinja.templates.TemplateResponse(
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


@router.get("/{agent_id}", summary="Agent detail modal")
async def agent_detail_modal(
    request: Request,
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    agent = await get_agent_by_id_service(agent_id, db)
    if not agent:
        raise HTTPException(status_code=404, detail="Agent not found")
    return jinja.templates.TemplateResponse(
        "agents/details_modal.html.j2",
        {"request": request, "agent": agent},
    )


@router.patch("/{agent_id}", summary="Toggle agent enabled/disabled")
async def toggle_agent_enabled(
    request: Request,
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> Response:
    try:
        agent = await toggle_agent_enabled_service(agent_id, user, db)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    return jinja.templates.TemplateResponse(
        "agents/row_fragment.html.j2",
        {"request": request, "agent": agent},
    )


@router.get("/{agent_id}/benchmarks", summary="Agent benchmark summary fragment")
async def agent_benchmark_summary_fragment(
    request: Request,
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    try:
        benchmarks_by_hash_type = await get_agent_benchmark_summary_service(
            agent_id, db
        )
    except AgentNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Agent not found"
        ) from e
    return jinja.templates.TemplateResponse(
        "agents/benchmarks_fragment.html.j2",
        {
            "request": request,
            "benchmarks_by_hash_type": benchmarks_by_hash_type,
        },
    )


@router.post(
    "/{agent_id}/benchmark", summary="Trigger agent benchmark run (set to pending)"
)
async def trigger_agent_benchmark(
    request: Request,
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> Response:
    try:
        agent = await trigger_agent_benchmark_service(agent_id, user, db)
    except PermissionError as e:
        raise HTTPException(status_code=403, detail=str(e)) from e
    except AgentNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    return jinja.templates.TemplateResponse(
        "agents/row_fragment.html.j2",
        {"request": request, "agent": agent},
    )
