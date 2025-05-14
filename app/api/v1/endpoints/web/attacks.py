from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.templating import _TemplateResponse

from app.core.deps import get_db
from app.core.services.attack_complexity_service import AttackEstimationService
from app.core.services.attack_service import (
    AttackNotFoundError,
    bulk_delete_attacks_service,
    duplicate_attack_service,
    estimate_attack_keyspace_and_complexity,
    move_attack_service,
)
from app.schemas.attack import (
    AttackBulkDeleteRequest,
    AttackMoveRequest,
    AttackOut,
    BruteForceMaskRequest,
    EstimateAttackRequest,
    EstimateAttackResponse,
)

# Use the project root 'templates' directory
templates = Jinja2Templates(directory="templates")

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


@router.post(
    "/estimate",
    summary="Estimate keyspace and complexity for unsaved attack config",
    description="Return an HTML fragment with keyspace and complexity score for the given attack config (unsaved).",
    status_code=status.HTTP_200_OK,
    response_model=EstimateAttackResponse,
)
async def estimate_attack(
    request: Request,
    attack_data: EstimateAttackRequest,
) -> _TemplateResponse:
    """
    Accepts attack config as JSON, returns HTML fragment for HTMX/Web UI. Always returns a rendered template fragment, not JSON.
    """
    try:
        result = await estimate_attack_keyspace_and_complexity(attack_data)
    except (ValueError, TypeError) as e:
        # Return error fragment for HTMX
        return templates.TemplateResponse(
            "fragments/alert.html",
            {"request": request, "message": str(e), "level": "error"},
            status_code=400,
        )
    return templates.TemplateResponse(
        "attacks/estimate_fragment.html",
        {"request": request, **result.model_dump()},
        status_code=200,
    )


class BruteForceMaskResponse(BaseModel):
    mask: str = Field(description="Generated mask string, e.g. '?1?1?1'")
    custom_charset: str = Field(description="Custom charset string, e.g. '?1=?l?d'")


@router.post(
    "/brute_force_mask",
    summary="Generate brute force mask and custom charset",
    description="Given charset options and length, return the mask and custom charset string for brute force attacks.",
    status_code=status.HTTP_200_OK,
)
async def brute_force_mask(
    data: BruteForceMaskRequest,
) -> BruteForceMaskResponse:
    """
    Accepts a JSON body with 'charset_options' (list[str]) and 'length' (int).
    Returns a dict with 'mask' and 'custom_charset'.
    """
    result = AttackEstimationService.generate_brute_force_mask_and_charset(
        data.charset_options, data.length
    )
    return BruteForceMaskResponse(**result)
