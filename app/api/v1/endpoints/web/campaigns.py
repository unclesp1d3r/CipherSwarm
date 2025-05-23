"""
🧭 JSON API Refactor - CipherSwarm Web UI

Follow these rules for all endpoints in this file:
1. Must return Pydantic models as JSON (no TemplateResponse or render()).
2. Must use FastAPI parameter types: Query, Path, Body, Depends, etc.
3. Must not parse inputs manually — let FastAPI validate and raise 422s.
4. Must use dependency-injected context for auth/user/project state.
5. Must not include database logic — delegate to a service layer (e.g. campaign_service).
6. Must not contain HTMX, Jinja, or fragment-rendering logic.
7. Must annotate live-update triggers with: # WS_TRIGGER: <event description>
8. Must update test files to expect JSON (not HTML) and preserve test coverage.

📘 See canonical task list and instructions:
↪️  docs/v2_rewrite_implementation_plan/side_quests/web_api_json_tasks.md
"""

import io
import json
from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    Form,
    HTTPException,
    Query,
    Request,
    UploadFile,
    status,
)
from fastapi.responses import Response, StreamingResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.authz import user_can_access_project
from app.core.deps import get_current_user, get_db
from app.core.services.campaign_service import (
    AttackNotFoundError,
    CampaignNotFoundError,
    add_attack_to_campaign_service,
    archive_campaign_service,
    create_campaign_service,
    export_campaign_template_service,
    get_campaign_metrics_service,
    get_campaign_progress_service,
    get_campaign_with_attack_summaries_service,
    list_campaigns_service,
    relaunch_campaign_service,
    reorder_attacks_service,
    start_campaign_service,
    stop_campaign_service,
    update_campaign_service,
)
from app.models.campaign import Campaign
from app.models.user import User
from app.schemas.attack import AttackCreate
from app.schemas.campaign import (
    CampaignCreate,
    CampaignRead,
    CampaignUpdate,
    ReorderAttacksRequest,
)
from app.schemas.schema_loader import validate_campaign_template
from app.web.templates import jinja

templates: Jinja2Templates = jinja.templates

router = APIRouter(prefix="/campaigns", tags=["Campaigns"])


# /api/v1/web/campaigns/{campaign_id}/reorder_attacks
@router.post(
    "/{campaign_id}/reorder_attacks",
    summary="Reorder attacks in a campaign",
    description="Accepts a list of attack IDs and updates their order (position) within the campaign.",
    status_code=status.HTTP_200_OK,
)
async def reorder_attacks(
    campaign_id: int,
    data: ReorderAttacksRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> dict[str, object]:
    campaign = await db.execute(
        select(Campaign)
        .options(selectinload(Campaign.project))
        .where(Campaign.id == campaign_id)
    )
    campaign_obj = campaign.scalar_one_or_none()
    if not campaign_obj or not user_can_access_project(
        current_user, campaign_obj.project, action="update"
    ):
        raise HTTPException(status_code=403, detail="Not authorized for this project.")
    try:
        await reorder_attacks_service(campaign_id, data.attack_ids, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    except AttackNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
        ) from e
    return {"success": True, "new_order": data.attack_ids}


# /api/v1/web/campaigns/{campaign_id}/start
@router.post(
    "/{campaign_id}/start",
    summary="Start campaign",
    description="Set campaign state to active.",
    status_code=status.HTTP_200_OK,
)
async def start_campaign(
    campaign_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> CampaignRead:
    campaign = await db.execute(
        select(Campaign)
        .options(selectinload(Campaign.project))
        .where(Campaign.id == campaign_id)
    )
    campaign_obj = campaign.scalar_one_or_none()
    if not campaign_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Campaign not found"
        )
    # Membership check: allow any member of the project
    if not any(
        assoc.project_id == campaign_obj.project_id and assoc.user_id == current_user.id
        for assoc in getattr(current_user, "project_associations", [])
    ):
        raise HTTPException(status_code=403, detail="Not authorized for this project.")
    if getattr(campaign_obj, "state", None) == "archived":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot start archived campaign.",
        )
    try:
        return await start_campaign_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


# /api/v1/web/campaigns/{campaign_id}/stop
@router.post(
    "/{campaign_id}/stop",
    summary="Stop campaign",
    description="Set campaign state to draft (stopped).",
    status_code=status.HTTP_200_OK,
)
async def stop_campaign(
    campaign_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> CampaignRead:
    campaign = await db.execute(
        select(Campaign)
        .options(selectinload(Campaign.project))
        .where(Campaign.id == campaign_id)
    )
    campaign_obj = campaign.scalar_one_or_none()
    if not campaign_obj:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Campaign not found"
        )
    # Membership check: allow any member of the project
    if not any(
        assoc.project_id == campaign_obj.project_id and assoc.user_id == current_user.id
        for assoc in getattr(current_user, "project_associations", [])
    ):
        raise HTTPException(status_code=403, detail="Not authorized for this project.")
    if getattr(campaign_obj, "state", None) == "archived":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot stop archived campaign.",
        )
    try:
        return await stop_campaign_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


@router.get(
    "/{campaign_id}",
    summary="Campaign detail view",
    description="Get campaign detail and attack summaries for the web UI.",
)
async def campaign_detail(
    request: Request,
    campaign_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    try:
        data = await get_campaign_with_attack_summaries_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    return templates.TemplateResponse(
        "campaigns/detail.html.j2",
        {"request": request, "campaign": data["campaign"], "attacks": data["attacks"]},
    )


# Helper to extract active project from request/cookie
async def get_active_project_id(request: Request) -> int | None:
    val = request.cookies.get("active_project_id")
    try:
        return int(val) if val else None
    except (ValueError, TypeError):
        return None


@router.get(
    "",
    summary="List campaigns",
    description="List campaigns with pagination and filtering. Returns an HTML fragment for HTMX.",
)
async def list_campaigns(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 20,
    name: Annotated[str | None, Query()] = None,
) -> Response:
    active_project_id = await get_active_project_id(request)
    if not active_project_id:
        raise HTTPException(status_code=403, detail="No active project selected.")
    # Check user membership
    if not any(
        assoc.project_id == active_project_id
        for assoc in current_user.project_associations
    ):
        raise HTTPException(status_code=403, detail="Not a member of this project.")
    skip = (page - 1) * size
    # Only list campaigns for the active project
    campaigns, total = await list_campaigns_service(
        db, skip=skip, limit=size, name_filter=name, project_id=active_project_id
    )
    total_pages = (total + size - 1) // size if size else 1
    return templates.TemplateResponse(
        "campaigns/list.html.j2",
        {
            "request": request,
            "campaigns": campaigns,
            "page": page,
            "size": size,
            "total": total,
            "total_pages": total_pages,
            "name": name,
        },
    )


@router.post(
    "",
    summary="Create a new campaign",
    description="Create a new campaign and return the updated campaign list as an HTML fragment for HTMX.",
)
async def create_campaign(
    request: Request,
    name: Annotated[str, Form()],
    project_id: Annotated[int, Form()],
    hash_list_id: Annotated[int, Form()],
    db: Annotated[AsyncSession, Depends(get_db)],
    description: Annotated[str | None, Form()] = None,
    priority: Annotated[int | None, Form()] = None,
) -> Response:
    errors = {}
    # Explicit validation for required fields
    if not name:
        errors["name"] = "Name is required."
    if not project_id:
        errors["project_id"] = "Project is required."
    if not hash_list_id:
        errors["hash_list_id"] = "Hash list is required."
    if errors:
        return templates.TemplateResponse(
            "campaigns/form.html.j2",
            {"request": request, "errors": errors, "form": request},
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    try:
        data = CampaignCreate(
            name=name,
            description=description,
            project_id=project_id,
            priority=priority if priority is not None else 0,
            hash_list_id=hash_list_id,
        )
    except ValueError as e:
        errors["form"] = str(e)
        return templates.TemplateResponse(
            "campaigns/form.html.j2",
            {"request": request, "errors": errors, "form": request},
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    try:
        await create_campaign_service(data, db)
    except ValueError as e:
        errors["form"] = str(e)
        return templates.TemplateResponse(
            "campaigns/form.html.j2",
            {"request": request, "errors": errors, "form": request},
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    # Use the same pagination logic as list_campaigns
    page = 1
    size = 20
    name_filter = None
    skip = (page - 1) * size
    campaigns, total = await list_campaigns_service(
        db, skip=skip, limit=size, name_filter=name_filter
    )
    total_pages = (total + size - 1) // size if size else 1
    return templates.TemplateResponse(
        "campaigns/list.html.j2",
        {
            "request": request,
            "campaigns": campaigns,
            "page": page,
            "size": size,
            "total": total,
            "total_pages": total_pages,
            "name": name_filter,
        },
        status_code=status.HTTP_201_CREATED,
    )


@router.patch(
    "/{campaign_id}",
    summary="Update campaign",
    description="Update campaign fields and return updated detail view as an HTML fragment for HTMX.",
)
async def update_campaign(
    request: Request,
    campaign_id: int,
    name: Annotated[str, Form()],
    description: Annotated[str | None, Form()],
    priority: Annotated[int | None, Form()],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    # Validate required fields
    errors = {}
    if not name or name.strip() == "":
        errors["name"] = "Name is required."
    if errors:
        return templates.TemplateResponse(
            "campaigns/form.html.j2",
            {
                "request": request,
                "errors": errors,
                "campaign": {
                    "id": campaign_id,
                    "name": name,
                    "description": description,
                    "priority": priority,
                },
                "action": f"/api/v1/web/campaigns/{campaign_id}",
            },
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    update_obj = CampaignUpdate(
        name=name.strip(),
        description=description.strip() if description else None,
        priority=priority,
    )
    try:
        await update_campaign_service(campaign_id, update_obj, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    data = await get_campaign_with_attack_summaries_service(campaign_id, db)
    return templates.TemplateResponse(
        "campaigns/detail.html.j2",
        {"request": request, "campaign": data["campaign"], "attacks": data["attacks"]},
    )


@router.delete(
    "/{campaign_id}",
    summary="Archive (soft-delete) campaign",
    description="Archive a campaign by setting its state to ARCHIVED. Returns updated campaign list as HTML fragment.",
    status_code=status.HTTP_200_OK,
)
async def archive_campaign(
    request: Request,
    campaign_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    try:
        campaign = await archive_campaign_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    if campaign.state == "archived":
        # Return updated campaign list fragment
        page = 1
        size = 20
        name_filter = None
        skip = (page - 1) * size
        campaigns, total = await list_campaigns_service(
            db, skip=skip, limit=size, name_filter=name_filter
        )
        total_pages = (total + size - 1) // size if size else 1
        return templates.TemplateResponse(
            "campaigns/list.html.j2",
            {
                "request": request,
                "campaigns": campaigns,
                "page": page,
                "size": size,
                "total": total,
                "total_pages": total_pages,
                "name": name_filter,
            },
            status_code=status.HTTP_200_OK,
        )
    # Should not reach here, but fallback
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{campaign_id}/add_attack",
    summary="Add attack to campaign",
    description="Create a new attack and attach it to the specified campaign. Returns updated campaign detail HTML fragment.",
    status_code=status.HTTP_201_CREATED,
)
async def add_attack_to_campaign(
    request: Request,
    campaign_id: int,
    data: AttackCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    try:
        await add_attack_to_campaign_service(campaign_id, data, db)
        # After adding, fetch updated campaign detail for HTMX
        detail = await get_campaign_with_attack_summaries_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
        ) from e
    return templates.TemplateResponse(
        "campaigns/detail.html.j2",
        {
            "request": request,
            "campaign": detail["campaign"],
            "attacks": detail["attacks"],
        },
        status_code=status.HTTP_201_CREATED,
    )


@router.get(
    "/{campaign_id}/progress",
    summary="Get campaign progress fragment",
    description="Returns a progress/status HTML fragment for the campaign (for HTMX polling).",
)
async def campaign_progress_fragment(
    request: Request,
    campaign_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    try:
        progress = await get_campaign_progress_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    return templates.TemplateResponse(
        "campaigns/progress_fragment.html.j2",
        {"request": request, "progress": progress, "campaign_id": campaign_id},
    )


@router.get(
    "/{campaign_id}/metrics",
    summary="Get campaign metrics fragment",
    description="Returns an aggregate metrics HTML fragment for the campaign (for HTMX polling).",
)
async def campaign_metrics_fragment(
    request: Request,
    campaign_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    try:
        metrics = await get_campaign_metrics_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    return templates.TemplateResponse(
        "campaigns/metrics_fragment.html.j2",
        {"request": request, "metrics": metrics, "campaign_id": campaign_id},
    )


@router.post(
    "/{campaign_id}/relaunch",
    summary="Relaunch failed or modified attacks in a campaign",
    description="Relaunches failed attacks or those with modified resources. Requires explicit confirmation. Returns updated campaign detail as an HTML fragment for HTMX.",
    status_code=status.HTTP_200_OK,
)
async def relaunch_campaign(
    request: Request,
    campaign_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    try:
        data = await relaunch_campaign_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    except HTTPException as e:
        # Return an error fragment for HTMX
        return templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": e.detail, "level": "error"},
            status_code=e.status_code,
        )
    # Return updated campaign detail fragment
    return templates.TemplateResponse(
        "campaigns/detail.html.j2",
        {"request": request, "campaign": data["campaign"], "attacks": data["attacks"]},
        status_code=status.HTTP_200_OK,
    )


@router.get(
    "/{campaign_id}/export",
    summary="Export campaign as JSON",
    description="Export a single campaign as a JSON file using the CampaignTemplate schema.",
    status_code=status.HTTP_200_OK,
)
async def export_campaign_json(
    campaign_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> StreamingResponse:
    # TODO: Add authentication/authorization
    template = await export_campaign_template_service(campaign_id, db)
    json_bytes = json.dumps(template.model_dump(mode="json"), indent=2).encode()
    return StreamingResponse(
        io.BytesIO(json_bytes),
        media_type="application/json",
        headers={
            "Content-Disposition": f"attachment; filename=campaign_{campaign_id}.json"
        },
    )


@router.post(
    "/import_json",
    summary="Import campaign from JSON",
    description="Import a campaign from a JSON file or payload and prefill the campaign editor modal.",
    status_code=status.HTTP_200_OK,
)
async def import_campaign_json(
    request: Request,
) -> Response:
    # Accept JSON body or file upload
    if request.headers.get("content-type", "").startswith("application/json"):
        data = await request.json()
    else:
        form = await request.form()
        file = form.get("file")
        if not file or not isinstance(file, UploadFile):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail="No file uploaded"
            )
        data = json.load(file.file)
    try:
        template = validate_campaign_template(data)
    except ValueError as e:
        return templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": f"Invalid template: {e}"},
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    # Prefill the campaign editor modal (stub for now)
    return templates.TemplateResponse(
        "campaigns/editor_modal.html.j2",
        {
            "request": request,
            "campaign": template,
            "imported": True,
            # Prefill all CampaignTemplate fields for UI
            "schema_version": template.schema_version,
            "name": template.name,
            "description": template.description,
            "attacks": template.attacks,
            "hash_list_id": template.hash_list_id,
        },
        status_code=status.HTTP_200_OK,
    )


@router.get(
    "/{campaign_id}/attacks_table_body",
    summary="Get attacks table body fragment",
    description="Returns the <tbody> fragment for the attacks table in a campaign detail view.",
)
async def campaign_attacks_table_body(
    request: Request,
    campaign_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    data = await get_campaign_with_attack_summaries_service(campaign_id, db)
    return templates.TemplateResponse(
        "attacks/attack_table_body.html.j2",
        {"request": request, "attacks": data["attacks"]},
        status_code=status.HTTP_200_OK,
    )
