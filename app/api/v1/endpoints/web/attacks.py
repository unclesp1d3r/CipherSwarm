from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.attack_service import (
    AttackNotFoundError,
    duplicate_attack_service,
    move_attack_service,
)
from app.schemas.attack import AttackMoveRequest, AttackOut

router = APIRouter()


# /api/v1/web/attacks/{attack_id}/move
@router.post(
    "/attacks/{attack_id}/move",
    summary="Move attack within campaign",
    description="Reposition an attack within its campaign (up, down, top, bottom).",
    tags=["Attacks"],
    status_code=status.HTTP_200_OK,
)
async def move_attack(
    attack_id: int,
    data: AttackMoveRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, object]:
    # TODO: Add authentication/authorization
    try:
        await move_attack_service(attack_id, data.direction, db)
    except AttackNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    return {"success": True, "attack_id": attack_id, "direction": data.direction.value}


# /api/v1/web/attacks/{attack_id}/duplicate
@router.post(
    "/attacks/{attack_id}/duplicate",
    summary="Duplicate attack in-place",
    description="Clone an attack in-place and insert the copy at the end of the campaign's attack list.",
    status_code=status.HTTP_201_CREATED,
)
async def duplicate_attack(
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AttackOut:
    # TODO: Add authentication/authorization
    try:
        new_attack = await duplicate_attack_service(attack_id, db)
    except AttackNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    return new_attack
