from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.attack_service import AttackNotFoundError, move_attack_service
from app.schemas.attack import AttackMoveRequest

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
