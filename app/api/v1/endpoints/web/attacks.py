import io
import json
from typing import Annotated, Any

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Query,
    Request,
    UploadFile,
    status,
)
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import ValidationError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.templating import _TemplateResponse

from app.core.authz import user_can_access_project
from app.core.deps import get_current_user, get_db
from app.core.services.attack_complexity_service import AttackEstimationService
from app.core.services.attack_service import (
    AttackEditConfirmationError,
    AttackNotFoundError,
    bulk_delete_attacks_service,
    create_attack_service,
    delete_attack_service,
    duplicate_attack_service,
    estimate_attack_keyspace_and_complexity,
    export_attack_json_service,
    get_attack_list_service,
    get_attack_performance_summary_service,
    get_attack_service,
    get_campaign_attack_table_fragment_service,
    update_attack_service,
)
from app.models.attack import Attack
from app.models.campaign import Campaign
from app.models.user import User
from app.schemas.attack import (
    AttackBulkDeleteRequest,
    AttackCreate,
    AttackEditorContext,
    AttackMoveRequest,
    AttackOut,
    AttackUpdate,
    BruteForceMaskRequest,
    BruteForceMaskResponse,
    EstimateAttackRequest,
    MaskValidationRequest,
    MaskValidationResponse,
)
from app.schemas.schema_loader import validate_attack_template
from app.web.templates import jinja

router = APIRouter(prefix="/attacks", tags=["Attacks"])

"""
Rules to follow:
1. Use @jinja.page() with a Pydantic return model
2. DO NOT use TemplateResponse or return dicts - absolutely avoid dict[str, object]
3. DO NOT put database logic here — call attack_service
4. Extract all context from DI dependencies, not request.query_params
5. Follow FastAPI idiomatic parameter usage
6. user_can() is available and implemented, so stop adding TODO items
"""


@router.get(
    "/editor-modal",
    summary="Attack editor modal",
    description="Return the attack editor modal context for a new or imported attack.",
)
@jinja.page("attacks/editor_modal.html.j2")
async def attack_editor_modal() -> AttackEditorContext:
    """
    Returns the context for the attack editor modal (empty for new attack).
    """
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
    current_user: Annotated[User, Depends(get_current_user)],
    request: Request,
) -> _TemplateResponse:
    attack = await db.execute(select(Attack).where(Attack.id == attack_id))
    attack_obj = attack.scalar_one_or_none()
    if not attack_obj:
        raise HTTPException(status_code=404, detail="Attack not found")
    campaign = await db.execute(
        select(Campaign).where(Campaign.id == attack_obj.campaign_id)
    )
    campaign_obj = campaign.scalar_one_or_none()
    if not campaign_obj or not user_can_access_project(
        current_user, campaign_obj.project, action="update"
    ):
        raise HTTPException(status_code=403, detail="Not authorized for this project.")
    try:
        attacks = await get_campaign_attack_table_fragment_service(
            attack_id, data.direction, db
        )
    except AttackNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    # Render only the <tbody> fragment for attacks table
    return jinja.templates.TemplateResponse(
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


def _set_default(data: dict[str, Any], key: str, value: object) -> None:
    if key not in data or data[key] is None:
        data[key] = value


def _patch_dictionary_attack_payload(data: dict[str, Any]) -> dict[str, Any]:
    # Legacy field mapping
    if "attack_mode" not in data and "mode" in data:
        data["attack_mode"] = data["mode"]
    if "min_length" in data and "increment_minimum" not in data:
        data["increment_minimum"] = data["min_length"]
    if "max_length" in data and "increment_maximum" not in data:
        data["increment_maximum"] = data["max_length"]
    # Set required numeric fields
    _set_default(data, "hash_type_id", 0)
    _set_default(data, "hash_mode", 0)
    _set_default(data, "min_length", 1)
    _set_default(data, "max_length", 1)
    _set_default(data, "wordlist_size", 10000)
    _set_default(data, "rule_count", 1)
    _set_default(data, "attack_mode_hashcat", 0)
    _set_default(data, "state", "pending")
    _set_default(data, "campaign_id", 0)
    _set_default(data, "hash_list_id", 0)
    _set_default(data, "name", "Test Attack")
    _set_default(data, "description", "")
    # Set required string fields
    _set_default(data, "hash_list_url", "dummy")
    _set_default(data, "hash_list_checksum", "dummy")
    # Set all legacy resource fields to None if not present
    for field in [
        "wordlist_guid",
        "rulelist_guid",
        "masklist_guid",
        "wordlist_inline",
        "rules_inline",
        "masks_inline",
        "position",
        "comment",
        "rule_file",
    ]:
        if field not in data:
            data[field] = None
    return data


def _patch_legacy_attack_payload(data: dict[str, Any]) -> dict[str, Any]:
    if data.get("attack_mode") == "dictionary" or data.get("mode") == "dictionary":
        return _patch_dictionary_attack_payload(data)
    return data


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
        return jinja.templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": str(e), "level": "error"},
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    return jinja.templates.TemplateResponse(
        "attacks/estimate_fragment.html.j2",
        {"request": request, **result.model_dump()},
        status_code=status.HTTP_200_OK,
    )


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
        return jinja.templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": f"Invalid template: {e}"},
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    # Prefill the attack editor modal (stub for now)
    return jinja.templates.TemplateResponse(
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
        return jinja.templates.TemplateResponse(
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
    # Ephemeral rule list is created and attached automatically; rule_file_uuid is not used
    modifiers = getattr(data, "modifiers", None)
    # Ensure left_rule UUID is included for test and UI compatibility
    left_rule_uuid = None
    if hasattr(updated_attack, "left_rule") and updated_attack.left_rule:
        left_rule_uuid = updated_attack.left_rule
    return jinja.templates.TemplateResponse(
        "attacks/editor_modal.html.j2",
        {
            "request": request,
            "attack": updated_attack,
            "imported": False,
            "keyspace": 0,
            "complexity": 0,
            "complexity_score": 1,
            "modifiers": modifiers,
            "rule_file_uuid": left_rule_uuid,
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
        data = _patch_legacy_attack_payload(data)
        # Validate and coerce to EstimateAttackRequest
        attack_req = EstimateAttackRequest.model_validate(data)
        # Compute keyspace/complexity
        result = await estimate_attack_keyspace_and_complexity(attack_req)
    except ValidationError as e:
        # Return error fragment for HTMX with field errors
        return jinja.templates.TemplateResponse(
            "fragments/alert.html.j2",
            {
                "request": request,
                "message": "Validation failed. Please correct the highlighted fields.",
                "error": "Validation failed.",
                "errors": e.errors(),
                "level": "error",
            },
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    except (ValueError, TypeError) as e:
        # Return error fragment for HTMX
        return jinja.templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": str(e), "error": str(e), "level": "error"},
            status_code=status.HTTP_400_BAD_REQUEST,
        )
    # Return a summary fragment
    return jinja.templates.TemplateResponse(
        "attacks/validate_summary_fragment.html.j2",
        {
            "request": request,
            "attack": attack_req,
            "keyspace": result.keyspace,
            "complexity": result.complexity_score,
            "complexity_score": result.complexity_score,
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
        return jinja.templates.TemplateResponse(
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
    # Ephemeral rule list is created and attached automatically; rule_file_uuid is not used
    modifiers = getattr(data, "modifiers", None)
    rule_file_uuid = None
    return jinja.templates.TemplateResponse(
        "attacks/editor_modal.html.j2",
        {
            "request": request,
            "attack": attack,
            "imported": False,
            "keyspace": 0,
            "complexity": 0,
            "complexity_score": 1,
            "modifiers": modifiers,
            "rule_file_uuid": rule_file_uuid,
        },
        status_code=status.HTTP_201_CREATED,
    )


@router.get("")
async def list_attacks(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 20,
    q: Annotated[
        str | None, Query(description="Search query for attack name/description")
    ] = None,
) -> _TemplateResponse:
    """
    Returns a paginated, searchable list of attacks as an HTML fragment for HTMX.
    """
    attacks, total, total_pages = await get_attack_list_service(
        db, page=page, size=size, q=q
    )
    return jinja.templates.TemplateResponse(
        "attacks/list.html.j2",
        {
            "request": request,
            "attacks": attacks,
            "page": page,
            "size": size,
            "total": total,
            "total_pages": total_pages,
            "q": q,
        },
        status_code=status.HTTP_200_OK,
    )


@router.get(
    "/attack_table_body",
    summary="Attack table body fragment",
    description="Returns only the <tbody> rows for the attack list, for HTMX swaps.",
)
async def attack_table_body_fragment(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    page: Annotated[int, Query(ge=1)] = 1,
    size: Annotated[int, Query(ge=1, le=100)] = 20,
    q: Annotated[
        str | None, Query(description="Search query for attack name/description")
    ] = None,
) -> _TemplateResponse:
    attacks, total, total_pages = await get_attack_list_service(
        db, page=page, size=size, q=q
    )
    return jinja.templates.TemplateResponse(
        "attacks/attack_table_body.html.j2",
        {
            "request": request,
            "attacks": attacks,
            "page": page,
            "size": size,
            "total": total,
            "total_pages": total_pages,
            "q": q,
        },
        status_code=status.HTTP_200_OK,
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
        return jinja.templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": str(e), "level": "error"},
            status_code=status.HTTP_404_NOT_FOUND,
        )
    return jinja.templates.TemplateResponse(
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
        return jinja.templates.TemplateResponse(
            "fragments/alert.html.j2",
            {"request": request, "message": str(e), "level": "error"},
            status_code=status.HTTP_404_NOT_FOUND,
        )
    return jinja.templates.TemplateResponse(
        "attacks/live_updates_toggle_fragment.html.j2",
        {"request": request, "live_updates_enabled": enabled, "attack": attack},
        status_code=status.HTTP_200_OK,
    )


@router.get(
    "/{attack_id}/view-modal",
    summary="View attack config and performance modal",
    description="Return an HTML modal fragment with attack config and performance for HTMX.",
    status_code=status.HTTP_200_OK,
)
@jinja.page("attacks/view_modal.html.j2")
async def view_attack_modal(
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, object]:
    """
    Returns a modal fragment with attack config and performance summary for HTMX.
    """
    try:
        perf = await get_attack_performance_summary_service(attack_id, db)
    except AttackNotFoundError as e:
        # Return error fragment for HTMX
        return {
            "error": str(e),
            "attack": None,
            "performance": None,
        }
    return {
        "attack": perf.attack,
        "performance": perf,
        "error": None,
    }


@router.delete(
    "/{attack_id}",
    summary="Delete attack",
    description="Delete an attack by ID. If not started, deletes from DB. If started, marks as abandoned and stops tasks. Cleans up ephemeral resources.",
    status_code=status.HTTP_200_OK,
)
async def delete_attack(
    attack_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> dict[str, bool | int]:
    # Authorization: fetch attack and campaign, check project access
    attack_obj = (
        await db.execute(select(Attack).where(Attack.id == attack_id))
    ).scalar_one_or_none()
    if not attack_obj:
        raise HTTPException(status_code=404, detail="Attack not found")
    campaign_obj = (
        await db.execute(select(Campaign).where(Campaign.id == attack_obj.campaign_id))
    ).scalar_one_or_none()
    if not campaign_obj or not user_can_access_project(
        current_user, campaign_obj.project, action="delete"
    ):
        raise HTTPException(status_code=403, detail="Not authorized for this project.")
    try:
        result = await delete_attack_service(attack_id, db)
    except AttackNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    return result


@router.post(
    "/validate_mask",
    summary="Validate hashcat mask syntax",
    description="Validate a hashcat mask string for syntax correctness. Returns valid/error JSON.",
    status_code=status.HTTP_200_OK,
    response_model=MaskValidationResponse,
)
async def validate_mask(
    data: MaskValidationRequest,
) -> MaskValidationResponse | JSONResponse:
    """
    Validate a hashcat mask string for syntax correctness. Returns valid/error JSON.
    """
    valid, error = AttackEstimationService.validate_mask_syntax(data.mask)
    if valid:
        return MaskValidationResponse(valid=True, error=None)
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content=MaskValidationResponse(valid=False, error=error).model_dump(),
    )
