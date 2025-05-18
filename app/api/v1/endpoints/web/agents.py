from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.datastructures import FormData
from starlette.responses import Response

from app.core.authz import user_can
from app.core.deps import get_current_user, get_db
from app.core.exceptions import AgentNotFoundError
from app.core.services.agent_service import (
    get_agent_benchmark_summary_service,
    get_agent_by_id_service,
    get_agent_error_log_service,
    list_agents_service,
    test_presigned_url_service,
    toggle_agent_enabled_service,
    trigger_agent_benchmark_service,
    update_agent_config_service,
)
from app.models.user import User
from app.schemas.agent import (
    AdvancedAgentConfiguration,
    AgentPresignedUrlTestRequest,
    AgentPresignedUrlTestResponse,
)
from app.web.templates import jinja

router = APIRouter(prefix="/agents", tags=["Agents"])


"""
Rules to follow:
1. Use @jinja.page() with a Pydantic return model
2. DO NOT use TemplateResponse or return dicts - absolutely avoid dict[str, object]
3. DO NOT put database logic here — call agent_service
4. Extract all context from DI dependencies, not request.query_params
5. Follow FastAPI idiomatic parameter usage
6. user_can() is available and implemented, so stop adding TODO items
"""


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


@router.post(
    "/{agent_id}/test_presigned",
    summary="Validate presigned S3/MinIO URL for agent resource",
)
async def test_agent_presigned_url(
    agent_id: int,
    payload: AgentPresignedUrlTestRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> JSONResponse:
    # Only admins can use this endpoint
    if (
        not user_can(user, "system", "create_users")
        and getattr(user, "role", None) != "admin"
    ):
        return JSONResponse(status_code=403, content={"error": "Admin only"})
    # Optionally: check agent exists (404 if not)
    agent = await get_agent_by_id_service(agent_id, db)
    if not agent:
        return JSONResponse(status_code=404, content={"error": "Agent not found"})
    # Test the presigned URL
    valid = await test_presigned_url_service(str(payload.url))
    return JSONResponse(content=AgentPresignedUrlTestResponse(valid=valid).model_dump())


def _parse_agent_config_form(
    form: FormData,
) -> dict[str, int | str | None | bool | object]:
    data = {k: v for k, v in form.items() if not hasattr(v, "filename")}
    if "agent_update_interval" in data:
        try:
            data["agent_update_interval"] = str(int(str(data["agent_update_interval"])))
        except ValueError:
            data["agent_update_interval"] = "30"
    for key in ["use_native_hashcat", "enable_additional_hash_types"]:
        if key in data:
            v = str(data[key])
            data[key] = "true" if v == "true" else "false"
    for key in ["backend_device", "opencl_devices"]:
        if key in data and str(data[key]) == "":
            data[key] = ""
    return {
        "agent_update_interval": int(str(data.get("agent_update_interval", "30"))),
        "use_native_hashcat": str(data.get("use_native_hashcat", "false")) == "true",
        "backend_device": str(data.get("backend_device")) or None,
        "opencl_devices": str(data.get("opencl_devices")) or None,
        "enable_additional_hash_types": str(
            data.get("enable_additional_hash_types", "false")
        )
        == "true",
    }


@router.patch("/{agent_id}/config", summary="Update agent advanced configuration")
async def update_agent_config(
    request: Request,
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    user: Annotated[User, Depends(get_current_user)],
) -> Response:
    # Accept both JSON and form data for HTMX
    try:
        if request.headers.get("content-type", "").startswith("application/json"):
            data = await request.json()
            config = AdvancedAgentConfiguration.model_validate(data)
        else:
            form = await request.form()
            config = AdvancedAgentConfiguration.model_validate(
                _parse_agent_config_form(form)
            )
    except (ValueError, ValidationError) as e:
        return jinja.templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": f"Validation error: {e}", "level": "error"},
            status_code=400,
        )
    # Enforce project membership and permissions (admin or project admin)
    try:
        await get_agent_by_id_service(agent_id, db)
    except AgentNotFoundError:
        raise HTTPException(status_code=404, detail="Agent not found") from None
    if not (
        getattr(user, "is_superuser", False)
        or user_can(user, "system", "update_agents")
    ):
        raise HTTPException(
            status_code=403, detail="Not authorized to update agent config"
        )
    try:
        updated_agent = await update_agent_config_service(agent_id, config, db)
    except AgentNotFoundError:
        raise HTTPException(status_code=404, detail="Agent not found") from None
    except ValueError as e:
        return jinja.templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": f"Update failed: {e}", "level": "error"},
            status_code=400,
        )
    # Return updated config fragment for HTMX
    return jinja.templates.TemplateResponse(
        "agents/details_modal.html.j2",
        {"request": request, "agent": updated_agent},
    )


@router.get("/{agent_id}/errors", summary="Agent error log fragment")
@jinja.page("agents/error_log_fragment.html.j2")
async def agent_error_log_fragment(
    agent_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, object]:
    errors = await get_agent_error_log_service(agent_id, db)
    return {"errors": errors}
