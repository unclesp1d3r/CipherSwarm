from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.campaign_service import (
    AttackNotFoundError,
    CampaignNotFoundError,
    attach_attack_to_campaign_service,
    create_campaign_service,
    delete_campaign_service,
    detach_attack_from_campaign_service,
    get_campaign_progress_service,
    get_campaign_service,
    list_campaigns_service,
    update_campaign_service,
)
from app.schemas.attack import AttackOut
from app.schemas.campaign import (
    CampaignCreate,
    CampaignProgress,
    CampaignRead,
    CampaignUpdate,
)

web_campaigns = APIRouter(prefix="/web/campaigns", tags=["Web Campaigns"])


@web_campaigns.get(
    "/",
    summary="List campaigns",
    description="List all campaigns.",
)
async def list_campaigns(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[CampaignRead]:
    return await list_campaigns_service(db)


@web_campaigns.get(
    "/{campaign_id}",
    summary="Get campaign",
    description="Get a campaign by ID.",
    responses={404: {"description": "Campaign not found"}},
)
async def get_campaign(
    campaign_id: UUID, db: Annotated[AsyncSession, Depends(get_db)]
) -> CampaignRead:
    try:
        return await get_campaign_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@web_campaigns.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    summary="Create campaign",
    description="Create a new campaign.",
)
async def create_campaign(
    data: CampaignCreate, db: Annotated[AsyncSession, Depends(get_db)]
) -> CampaignRead:
    return await create_campaign_service(data, db)


@web_campaigns.put(
    "/{campaign_id}",
    summary="Update campaign",
    description="Update a campaign by ID.",
    responses={404: {"description": "Campaign not found"}},
)
async def update_campaign(
    campaign_id: UUID,
    data: CampaignUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> CampaignRead:
    try:
        return await update_campaign_service(campaign_id, data, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@web_campaigns.delete(
    "/{campaign_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete campaign",
    description="Delete a campaign by ID.",
    responses={404: {"description": "Campaign not found"}},
)
async def delete_campaign(
    campaign_id: UUID, db: Annotated[AsyncSession, Depends(get_db)]
) -> None:
    try:
        await delete_campaign_service(campaign_id, db)
    except CampaignNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@web_campaigns.post(
    "/{campaign_id}/attacks/{attack_id}/attach",
    summary="Attach attack to campaign",
    description="Attach an attack to a campaign.",
    responses={404: {"description": "Campaign or attack not found"}},
)
async def attach_attack_to_campaign(
    campaign_id: UUID,
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AttackOut:
    try:
        return await attach_attack_to_campaign_service(campaign_id, attack_id, db)
    except (CampaignNotFoundError, AttackNotFoundError) as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e


@web_campaigns.post(
    "/{campaign_id}/attacks/{attack_id}/detach",
    summary="Detach attack from campaign",
    description="Detach an attack from a campaign.",
    responses={404: {"description": "Campaign or attack not found"}},
)
async def detach_attack_from_campaign(
    campaign_id: UUID,
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AttackOut:
    try:
        return await detach_attack_from_campaign_service(campaign_id, attack_id, db)
    except (CampaignNotFoundError, AttackNotFoundError) as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e


@web_campaigns.get(
    "/{campaign_id}/progress",
    summary="Get campaign progress",
    description="Get the number of active agents and total tasks for a campaign.",
    responses={404: {"description": "Campaign not found"}},
)
async def get_campaign_progress(
    campaign_id: UUID, db: Annotated[AsyncSession, Depends(get_db)]
) -> CampaignProgress:
    return await get_campaign_progress_service(campaign_id, db)
