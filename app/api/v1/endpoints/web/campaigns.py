from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.campaign_service import (
    AttackNotFoundError,
    CampaignNotFoundError,
    reorder_attacks_service,
)
from app.schemas.campaign import ReorderAttacksRequest

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
