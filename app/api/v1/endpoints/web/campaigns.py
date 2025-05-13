from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import Response
from fastapi.templating import Jinja2Templates
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.campaign_service import (
    AttackNotFoundError,
    CampaignNotFoundError,
    get_campaign_with_attack_summaries_service,
    list_campaigns_service,
    reorder_attacks_service,
    start_campaign_service,
    stop_campaign_service,
)
from app.schemas.campaign import CampaignRead, ReorderAttacksRequest

TEMPLATES_DIR = (
    Path(__file__).resolve().parent.parent.parent.parent / "templates"
).resolve()
templates = Jinja2Templates(directory=str(TEMPLATES_DIR))

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
    data = await get_campaign_with_attack_summaries_service(campaign_id, db)
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
