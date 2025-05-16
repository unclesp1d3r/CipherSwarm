import io
import json
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Request, UploadFile, status
from fastapi.responses import JSONResponse, StreamingResponse
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
    export_attack_json_service,
    get_attack_performance_summary_service,
    get_attack_service,
    get_campaign_attack_table_fragment_service,
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
)
from app.schemas.schema_loader import validate_attack_template
from app.web.templates import jinja

# Use the project root 'templates' directory
templates = Jinja2Templates(directory="templates")

router = APIRouter(prefix="/attacks", tags=["Attacks"])


class AttackEditorContext(BaseModel):
    attack: Any = None
    imported: bool = False
    keyspace: int = 0
    complexity: int = 0
    complexity_score: int = 1


@router.get("/editor-modal")
@jinja.page("attacks/editor_modal.html.j2")
async def attack_editor_modal() -> AttackEditorContext:
    return AttackEditorContext()


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
    request: Request,
) -> _TemplateResponse:
    # TODO: Add authentication/authorization
    try:
        attacks = await get_campaign_attack_table_fragment_service(
            attack_id, data.direction, db
        )
    except AttackNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    # Render only the <tbody> fragment for attacks table
    return templates.TemplateResponse(
        "attacks/attack_table_body.html.j2",
        {"request": request, "attacks": attacks},
        status_code=status.HTTP_200_OK,
    )


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
        template = await export_attack_json_service(attack_id, db)
    except AttackNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    json_bytes = template.model_dump_json().encode()
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
    response_model=None,
)
async def create_attack(
    request: Request,
    data: AttackCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> _TemplateResponse | JSONResponse:
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
    # If the request is for JSON (test or API client), return a JSON response with the attack ID
    if request.headers.get("accept", "").startswith("application/json"):
        return JSONResponse({"id": attack.id}, status_code=status.HTTP_201_CREATED)
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


@router.get(
    "/{attack_id}",
    summary="Get attack by ID",
    description="Get a single attack by its ID as JSON.",
    status_code=status.HTTP_200_OK,
)
async def get_attack(
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> AttackOut:
    try:
        attack = await get_attack_service(attack_id, db)
        return AttackOut.model_validate(attack, from_attributes=True)
    except AttackNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e


class MaskValidationRequest(BaseModel):
    mask: str = Field(..., description="Hashcat mask string to validate")


class MaskValidationResponse(BaseModel):
    valid: bool
    error: str | None = None


@router.post(
    "/validate_mask",
    summary="Validate hashcat mask syntax",
    description="Validate a hashcat mask string for syntax correctness. Returns valid/error JSON.",
    status_code=status.HTTP_200_OK,
    response_model=None,
)
async def validate_mask(
    data: MaskValidationRequest,
) -> JSONResponse | MaskValidationResponse:
    valid, error = AttackEstimationService.validate_mask_syntax(data.mask)
    if valid:
        return MaskValidationResponse(valid=True, error=None)
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=MaskValidationResponse(valid=False, error=error).model_dump(),
    )


@router.post(
    "/brute_force_preview_fragment",
    summary="HTMX fragment for brute force mask/charset preview",
    description="Returns a rendered fragment for the brute force charset/mask preview.",
    status_code=status.HTTP_200_OK,
)
async def brute_force_preview_fragment(
    request: Request,
    data: BruteForceMaskRequest,
) -> _TemplateResponse:
    result = AttackEstimationService.generate_brute_force_mask_and_charset(
        data.charset_options, data.length
    )
    return templates.TemplateResponse(
        "attacks/brute_force_preview_fragment.html.j2",
        {"request": request, **result},
        status_code=status.HTTP_200_OK,
    )


@router.get(
    "/{attack_id}/performance",
    summary="Attack performance summary",
    description="Return an HTML fragment with hashes/sec, total hashes, agent count, and ETA for the attack.",
    status_code=status.HTTP_200_OK,
)
async def attack_performance_summary(
    request: Request,
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> _TemplateResponse:
    try:
        perf = await get_attack_performance_summary_service(attack_id, db)
    except AttackNotFoundError as e:
        return templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": str(e), "level": "error"},
            status_code=status.HTTP_404_NOT_FOUND,
        )
    return templates.TemplateResponse(
        "attacks/performance_summary_fragment.html.j2",
        {"request": request, **perf.model_dump()},
        status_code=status.HTTP_200_OK,
    )


@router.post(
    "/{attack_id}/disable_live_updates",
    summary="Toggle live updates for attack (UI only)",
    description="Enable or disable websocket/HTMX live updates for this attack for the current user. This is a UI preference only and is not persisted in the backend.",
    status_code=status.HTTP_200_OK,
)
async def disable_live_updates(
    request: Request,
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> _TemplateResponse:
    body = await request.body()
    enabled = None
    if body:
        try:
            data = await request.json()
            enabled = data.get("enabled")
        except (ValueError, json.JSONDecodeError):
            enabled = None
    # Default: toggle if not provided
    if enabled is None:
        # Try to get from cookie, else default to True
        enabled_cookie = request.cookies.get(f"live_updates_{attack_id}")
        enabled = enabled_cookie != "true" if enabled_cookie is not None else False
    # Set cookie in response (handled by frontend JS/HTMX, not backend)
    # Fetch attack for context only
    try:
        attack = await get_attack_service(attack_id, db)
    except AttackNotFoundError as e:
        return templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": str(e), "level": "error"},
            status_code=status.HTTP_404_NOT_FOUND,
        )
    return templates.TemplateResponse(
        "attacks/live_updates_toggle_fragment.html.j2",
        {"request": request, "live_updates_enabled": enabled, "attack": attack},
        status_code=status.HTTP_200_OK,
    )
