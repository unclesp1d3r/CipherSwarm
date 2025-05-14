from typing import Annotated, Any

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
from fastapi.responses import Response
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.datastructures import FormData

from app.core.deps import get_db
from app.core.services.campaign_service import (
    AttackNotFoundError,
    CampaignNotFoundError,
    add_attack_to_campaign_service,
    archive_campaign_service,
    create_campaign_service,
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
from app.schemas.attack import AttackCreate
from app.schemas.campaign import (
    CampaignCreate,
    CampaignRead,
    CampaignUpdate,
    ReorderAttacksRequest,
)

templates = Jinja2Templates(directory="templates")

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
) -> dict[str, object]:
    # TODO: Add authentication/authorization
    try:
        await reorder_attacks_service(campaign_id, data.attack_ids, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except AttackNotFoundError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    # TODO: For now, return a simple JSON response; replace with HTML fragment for HTMX later
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
) -> CampaignRead:
    # TODO: Add authentication/authorization
    try:
        return await start_campaign_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


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
) -> CampaignRead:
    # TODO: Add authentication/authorization
    try:
        return await stop_campaign_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


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
        raise HTTPException(status_code=404, detail=str(e)) from e
    return templates.TemplateResponse(
        "campaigns/detail.html",
        {"request": request, "campaign": data["campaign"], "attacks": data["attacks"]},
    )


@router.get(
    "",
    summary="List campaigns",
    description="List campaigns with pagination and filtering. Returns an HTML fragment for HTMX.",
)
async def list_campaigns(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 20,
    name: Annotated[str | None, Query()] = None,
) -> Response:
    skip = (page - 1) * size
    campaigns, total = await list_campaigns_service(
        db, skip=skip, limit=size, name_filter=name
    )
    total_pages = (total + size - 1) // size if size else 1
    return templates.TemplateResponse(
        "campaigns/list.html",
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


def _safe_int(val: object) -> int:
    if isinstance(val, str):
        try:
            return int(val)
        except ValueError:
            return 0
    return 0


def _extract_str(form: FormData, key: str) -> str:
    val = form.get(key)
    if isinstance(val, list):
        val = val[0]
    if val is None:
        return ""
    return str(val)


def _extract_int(form: FormData, key: str) -> int:
    val = form.get(key)
    if isinstance(val, list):
        val = val[0]
    if isinstance(val, UploadFile):
        return 0
    return _safe_int(val)


def parse_campaign_form(form: FormData) -> dict[str, Any]:
    return {
        "name": _extract_str(form, "name"),
        "description": _extract_str(form, "description"),
        "project_id": _extract_int(form, "project_id"),
        "priority": _extract_int(form, "priority"),
        "hash_list_id": _extract_int(form, "hash_list_id"),
    }


@router.post(
    "",
    summary="Create a new campaign",
    description="Create a new campaign and return the updated campaign list as an HTML fragment for HTMX.",
)
async def create_campaign(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    form = await request.form()
    errors = {}
    parsed = parse_campaign_form(form)
    # Explicit validation for required fields
    if not parsed["name"]:
        errors["name"] = "Name is required."
    if not parsed["project_id"]:
        errors["project_id"] = "Project is required."
    if not parsed["hash_list_id"]:
        errors["hash_list_id"] = "Hash list is required."
    if errors:
        return templates.TemplateResponse(
            "campaigns/form.html",
            {"request": request, "errors": errors, "form": form},
            status_code=400,
        )
    try:
        data = CampaignCreate(**parsed)
    except ValueError as e:
        errors["form"] = str(e)
        return templates.TemplateResponse(
            "campaigns/form.html",
            {"request": request, "errors": errors, "form": form},
            status_code=400,
        )
    # Only proceed if data is valid
    try:
        await create_campaign_service(data, db)
    except ValueError as e:
        errors["form"] = str(e)
        return templates.TemplateResponse(
            "campaigns/form.html",
            {"request": request, "errors": errors, "form": form},
            status_code=400,
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
        "campaigns/list.html",
        {
            "request": request,
            "campaigns": campaigns,
            "page": page,
            "size": size,
            "total": total,
            "total_pages": total_pages,
            "name": name_filter,
        },
        status_code=201,
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
            "campaigns/form.html",
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
            status_code=400,
        )
    update_obj = CampaignUpdate(
        name=name.strip(),
        description=description.strip() if description else None,
        priority=priority,
    )
    try:
        await update_campaign_service(campaign_id, update_obj, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    data = await get_campaign_with_attack_summaries_service(campaign_id, db)
    return templates.TemplateResponse(
        "campaigns/detail.html",
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
        raise HTTPException(status_code=404, detail=str(e)) from e
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
            "campaigns/list.html",
            {
                "request": request,
                "campaigns": campaigns,
                "page": page,
                "size": size,
                "total": total,
                "total_pages": total_pages,
                "name": name_filter,
            },
            status_code=200,
        )
    # Should not reach here, but fallback
    return Response(status_code=204)


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
        raise HTTPException(status_code=404, detail=str(e)) from e
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    return templates.TemplateResponse(
        "campaigns/detail.html",
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
        raise HTTPException(status_code=404, detail=str(e)) from e
    return templates.TemplateResponse(
        "campaigns/progress_fragment.html",
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
        raise HTTPException(status_code=404, detail=str(e)) from e
    return templates.TemplateResponse(
        "campaigns/metrics_fragment.html",
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
        raise HTTPException(status_code=404, detail=str(e)) from e
    except HTTPException as e:
        # Return an error fragment for HTMX
        return templates.TemplateResponse(
            "fragments/alert.html",
            {"request": request, "message": e.detail, "level": "error"},
            status_code=e.status_code,
        )
    # Return updated campaign detail fragment
    return templates.TemplateResponse(
        "campaigns/detail.html",
        {"request": request, "campaign": data["campaign"], "attacks": data["attacks"]},
        status_code=200,
    )
