import io
import json
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, status
from fastapi.responses import StreamingResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field, ValidationError
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.templating import _TemplateResponse

from app.core.deps import get_db
from app.core.services.attack_complexity_service import AttackEstimationService
from app.core.services.attack_service import (
    AttackEditConfirmationError,
    AttackNotFoundError,
    bulk_delete_attacks_service,
    create_attack_service,
    duplicate_attack_service,
    estimate_attack_keyspace_and_complexity,
    export_attack_template_service,
    move_attack_service,
    update_attack_service,
)
from app.schemas.attack import (
    AttackBulkDeleteRequest,
    AttackCreate,
    AttackMoveRequest,
    AttackOut,
    AttackUpdate,
    BruteForceMaskRequest,
    EstimateAttackRequest,
    EstimateAttackResponse,
)
from app.schemas.schema_loader import validate_attack_template

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
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
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
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
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
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail={"detail": str(e)}
        ) from e
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
            "fragments/alert.html.j2",
            {"request": request, "message": str(e), "level": "error"},
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    return templates.TemplateResponse(
        "attacks/estimate_fragment.html.j2",
        {"request": request, **result.model_dump()},
        status_code=status.HTTP_200_OK,
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


@router.get(
    "/{attack_id}/export",
    summary="Export attack as JSON",
    description="Export a single attack as a JSON file using the AttackTemplate schema.",
    status_code=status.HTTP_200_OK,
)
async def export_attack_json(
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> StreamingResponse:
    # TODO: Add authentication/authorization
    try:
        template = await export_attack_template_service(attack_id, db)
    except AttackNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    json_bytes = json.dumps(template.model_dump(mode="json"), indent=2).encode()
    return StreamingResponse(
        io.BytesIO(json_bytes),
        media_type="application/json",
        headers={
            "Content-Disposition": f"attachment; filename=attack_{attack_id}.json"
        },
    )


@router.post(
    "/import_json",
    summary="Import attack from JSON",
    description="Import an attack from a JSON file or payload and prefill the attack editor modal.",
    status_code=status.HTTP_200_OK,
)
async def import_attack_json(
    request: Request,
) -> _TemplateResponse:
    # Accept JSON body or file upload
    if request.headers.get("content-type", "").startswith("application/json"):
        data = await request.json()
    else:
        form = await request.form()
        file = form.get("file")
        if not file or not isinstance(file, UploadFile):
            raise HTTPException(status_code=400, detail="No file uploaded")
        data = json.load(file.file)
    try:
        template = validate_attack_template(data)
    except ValueError as e:
        return templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": f"Invalid template: {e}"},
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    # Prefill the attack editor modal (stub for now)
    return templates.TemplateResponse(
        "attacks/editor_modal.html.j2",
        {
            "request": request,
            "attack": template,
            "imported": True,
            "keyspace": 0,
            "complexity": 0,
            "complexity_score": 1,
            # Prefill all AttackTemplate fields for UI
            "mode": template.mode,
            "wordlist_guid": template.wordlist_guid,
            "rule_file": template.rule_file,
            "min_length": template.min_length,
            "max_length": template.max_length,
            "masks": template.masks,
            "wordlist_inline": template.wordlist_inline,
            "masks_inline": template.masks_inline,
        },
        status_code=status.HTTP_200_OK,
    )


@router.patch(
    "/{attack_id}",
    summary="Edit attack configuration",
    description="Edit an attack. If the attack is running or completed, require confirmation before resetting to pending and applying changes.",
    status_code=status.HTTP_200_OK,
)
async def edit_attack(
    request: Request,
    attack_id: int,
    data: AttackUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> _TemplateResponse:
    # TODO: Add authentication/authorization
    try:
        updated_attack = await update_attack_service(
            attack_id, data, db, confirm=getattr(data, "confirm", False)
        )
    except AttackEditConfirmationError as e:
        # Return a warning fragment for HTMX
        return templates.TemplateResponse(
            "fragments/attack_edit_warning.html.j2",
            {
                "request": request,
                "attack": e.attack,
                "warning": f"This attack is currently {e.attack.state.value}. Editing will reset it to pending and reprocess. Confirm to proceed.",
                "confirm_url": f"/api/v1/web/attacks/{attack_id}",
                "data": data.model_dump(),
            },
            status_code=status.HTTP_409_CONFLICT,
        )
    except AttackNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    return templates.TemplateResponse(
        "attacks/editor_modal.html.j2",
        {
            "request": request,
            "attack": updated_attack,
            "imported": False,
            "keyspace": 0,
            "complexity": 0,
            "complexity_score": 1,
        },
        status_code=status.HTTP_200_OK,
    )


@router.post(
    "/validate",
    summary="Validate attack configuration (dry-run)",
    description="Validate an attack config and return either errors or a keyspace/complexity summary as an HTML fragment.",
    status_code=status.HTTP_200_OK,
)
async def validate_attack(
    request: Request,
) -> _TemplateResponse:
    """
    Accepts attack config as JSON, returns HTML fragment for HTMX/Web UI. Returns error fragment or summary fragment.
    """
    try:
        data = await request.json()
        template = validate_attack_template(data)
        # TODO: Compute keyspace/complexity here if needed (stub for now)
        keyspace = 0
        complexity = 0
        complexity_score = 1
    except (ValueError, TypeError) as e:
        # Return error fragment for HTMX
        return templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": str(e), "level": "error"},
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    # Return a summary fragment (stub for now)
    return templates.TemplateResponse(
        "attacks/validate_summary_fragment.html.j2",
        {
            "request": request,
            "attack": template,
            "keyspace": keyspace,
            "complexity": complexity,
            "complexity_score": complexity_score,
        },
        status_code=status.HTTP_200_OK,
    )


@router.post(
    "",
    summary="Create a new attack",
    description="Create a new attack, supporting ephemeral mask lists via masks_inline.",
    status_code=status.HTTP_201_CREATED,
)
async def create_attack(
    request: Request,
    data: AttackCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> _TemplateResponse:
    # TODO: Add authentication/authorization
    try:
        attack = await create_attack_service(data, db)
    except ValidationError as e:
        # Pass structured validation errors to the template for field-level UI feedback.
        # This enables the frontend to highlight invalid fields and display per-field error messages using Flowbite's error style.
        return templates.TemplateResponse(
            "fragments/alert.html.j2",
            {
                "request": request,
                "message": "Validation failed. Please correct the highlighted fields.",
                "errors": e.errors(),  # List of error dicts: {loc, msg, type}
                "level": "error",
            },
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    return templates.TemplateResponse(
        "attacks/editor_modal.html.j2",
        {
            "request": request,
            "attack": attack,
            "imported": False,
            "keyspace": 0,
            "complexity": 0,
            "complexity_score": 1,
        },
        status_code=status.HTTP_201_CREATED,
    )
