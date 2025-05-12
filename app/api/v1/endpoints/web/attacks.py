from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.attack_service import (
    AttackNotFoundError,
    bulk_delete_attacks_service,
    duplicate_attack_service,
    move_attack_service,
)
from app.schemas.attack import AttackBulkDeleteRequest, AttackMoveRequest, AttackOut

router = APIRouter(prefix="/attacks", tags=["Attacks"])


# /api/v1/web/attacks/{attack_id}/move
@router.post(
    "/{attack_id}/move",
    summary="Move attack within campaign",
    description="Reposition an attack within its campaign (up, down, top, bottom).",
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
    "/{attack_id}/duplicate",
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


# /api/v1/web/attacks/bulk
@router.delete(
    "/bulk",
    summary="Bulk delete attacks",
    description="Delete multiple attacks by their IDs in a single request.",
    status_code=status.HTTP_200_OK,
)
async def bulk_delete_attacks(
    data: AttackBulkDeleteRequest,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, list[int]]:
    # TODO: Add authentication/authorization
    if not data.attack_ids:
        return {"deleted_ids": [], "not_found_ids": []}
    try:
        result = await bulk_delete_attacks_service(data.attack_ids, db)
    except AttackNotFoundError as e:
        raise HTTPException(status_code=404, detail={"detail": str(e)}) from e
    return result
