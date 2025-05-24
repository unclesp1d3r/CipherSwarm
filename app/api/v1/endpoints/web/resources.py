"""
Follow these rules for all endpoints in this file:
1. Must return Pydantic models as JSON (no TemplateResponse or render()).
2. Must use FastAPI parameter types: Query, Path, Body, Depends, etc.
3. Must not parse inputs manually — let FastAPI validate and raise 422s.
4. Must use dependency-injected context for auth/user/project state.
5. Must not include database logic — delegate to a service layer (e.g. campaign_service).
6. Must not contain HTMX, Jinja, or fragment-rendering logic.
7. Must annotate live-update triggers with: # WS_TRIGGER: <event description>
"""

from typing import Annotated
from uuid import UUID

from fastapi import (
    APIRouter,
    Body,
    Depends,
    Form,
    HTTPException,
    Path,
    status,
)
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.authz import user_can_access_project_by_id
from app.core.config import settings
from app.core.deps import get_current_user, get_db
from app.core.services.resource_service import (
    EDITABLE_RESOURCE_TYPES,
    add_resource_line_service,
    check_project_access,
    check_resource_editable,
    create_resource_and_presign_service,
    delete_resource_line_service,
    get_resource_content_service,
    get_resource_lines_service,
    get_resource_or_404,
    is_resource_editable,
    list_resources_service,
    list_rulelists_service,
    list_wordlists_service,
    update_resource_line_service,
    validate_resource_lines_service,
)
from app.models.attack_resource_file import AttackResourceFile, AttackResourceType
from app.models.user import User
from app.schemas.resource import (
    AttackBasic,
    ResourceContentResponse,
    ResourceDetailResponse,
    ResourceLinesResponse,
    ResourceListResponse,
    ResourcePreviewResponse,
    ResourceUploadMeta,
    ResourceUploadResponse,
    RulelistDropdownResponse,
    RulelistItem,
    WordlistDropdownResponse,
    WordlistItem,
)

router = APIRouter(prefix="/resources", tags=["Resources"])


async def _get_resource_if_accessable(
    resource_id: UUID,
    db: AsyncSession,
    current_user: User,
) -> AttackResourceFile:
    resource = await get_resource_or_404(resource_id, db)
    await check_project_access(resource, current_user, db)
    return resource


@router.get(
    "/{resource_id}/content",
    summary="Get raw editable text content for a resource",
    description="Return the raw text content for eligible resources (mask, rule, wordlist, charset). Enforces editability constraints.",
)
async def get_resource_content(
    resource_id: Annotated[
        UUID, Path(description="The resource ID to get the content for")
    ],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ResourceContentResponse:
    (
        resource_model,
        content_str,
        error_message,
        status_code,
        editable,
    ) = await get_resource_content_service(resource_id, db)
    if error_message:
        raise HTTPException(status_code=status_code, detail=error_message)

    if not resource_model:
        raise HTTPException(status_code=404, detail="Resource not found")

    final_content = content_str if content_str is not None else ""

    return ResourceContentResponse(
        id=resource_model.id,
        file_name=resource_model.file_name,
        resource_type=resource_model.resource_type,
        line_count=resource_model.line_count,
        byte_size=resource_model.byte_size,
        updated_at=resource_model.updated_at,
        content=final_content,
        editable=editable,
    )


@router.get(
    "/wordlists",
    summary="List all wordlist resources for dropdown",
    description="Return all wordlist resources, sorted by last modified, with search and entry count support.",
)
async def list_wordlists(
    db: Annotated[AsyncSession, Depends(get_db)],
    q: str | None = None,
) -> WordlistDropdownResponse:
    wordlist_models = await list_wordlists_service(db, q)
    wordlist_items = [
        WordlistItem(id=wl.id, file_name=wl.file_name, line_count=wl.line_count)
        for wl in wordlist_models
    ]
    return WordlistDropdownResponse(wordlists=wordlist_items)


@router.get(
    "/rulelists",
    summary="List all rule list resources for dropdown",
    description="Return all rule list resources, sorted by last modified, with search and entry count support.",
)
async def list_rulelists(
    db: Annotated[AsyncSession, Depends(get_db)],
    q: str | None = None,
) -> RulelistDropdownResponse:
    rulelist_models = await list_rulelists_service(db, q)
    rulelist_items = [
        RulelistItem(id=rl.id, file_name=rl.file_name, line_count=rl.line_count)
        for rl in rulelist_models
    ]
    return RulelistDropdownResponse(rulelists=rulelist_items)


# Helper: check if resource is editable
async def _check_editable(resource: AttackResourceFile) -> None:
    if resource.resource_type == AttackResourceType.DYNAMIC_WORD_LIST:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Editing not allowed for dynamic word lists.",
        )
    if (
        resource.line_count is not None
        and settings.RESOURCE_EDIT_MAX_LINES is not None
        and resource.line_count > settings.RESOURCE_EDIT_MAX_LINES
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Resource too large for in-browser editing.",
        )
    if (
        resource.byte_size is not None
        and settings.RESOURCE_EDIT_MAX_SIZE_MB is not None
        and resource.byte_size > settings.RESOURCE_EDIT_MAX_SIZE_MB * 1024 * 1024
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Resource too large for in-browser editing.",
        )
    if resource.resource_type not in EDITABLE_RESOURCE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Resource type not editable."
        )


def _enforce_editable(resource: AttackResourceFile) -> None:
    if not is_resource_editable(resource):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Editing is disabled for this resource (read-only or too large).",
        )


@router.get(
    "/{resource_id}/lines",
    summary="List lines in a file-backed resource (paginated, optionally validated)",
    description="Return a paginated list of lines in the resource for in-browser editing. Supports ?validate=true for batch validation.",
)
async def list_resource_lines(
    resource_id: Annotated[UUID, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    page: int = 1,
    page_size: int = 100,
    validate: bool = False,
) -> ResourceLinesResponse:
    resource_model = await _get_resource_if_accessable(resource_id, db, current_user)

    if resource_model.resource_type not in EDITABLE_RESOURCE_TYPES:
        raise HTTPException(
            status_code=403,
            detail="Ephemeral resources are not editable via this endpoint.",
        )
    _enforce_editable(resource_model)
    lines = await get_resource_lines_service(resource_id, db, page, page_size)
    if validate:
        from app.core.services.resource_service import _validate_line

        validated_lines = []
        for line in lines:
            valid, error = _validate_line(line.content, resource_model.resource_type)
            validated_lines.append(
                type(line)(
                    id=line.id,
                    index=line.index,
                    content=line.content,
                    valid=valid,
                    error_message=error,
                )
            )
        lines = validated_lines
    return ResourceLinesResponse(lines=lines, resource_id=resource_id)


@router.post(
    "/{resource_id}/lines",
    summary="Add a new line to a file-backed resource (204 No Content)",
    description="Add a new line to the resource. Returns 204 No Content on success, 422 JSON on validation error.",
    status_code=204,
)
async def add_resource_line(
    resource_id: Annotated[UUID, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    line: Annotated[str, Body(embed=True, description="Line content to add")],
) -> None:
    resource = await _get_resource_if_accessable(resource_id, db, current_user)

    _enforce_editable(resource)
    await add_resource_line_service(resource_id, db, line)


@router.patch(
    "/{resource_id}/lines/{line_id}",
    summary="Update a line in a file-backed resource (204 No Content)",
    description="Update an existing line in the resource. Returns 204 No Content on success, 422 JSON on validation error.",
    status_code=204,
)
async def update_resource_line(
    resource_id: Annotated[UUID, Path()],
    line_id: Annotated[int, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    line: Annotated[str, Body(embed=True, description="New line content")],
) -> None:
    resource = await _get_resource_if_accessable(resource_id, db, current_user)

    _enforce_editable(resource)
    await update_resource_line_service(resource_id, line_id, db, line)


@router.delete(
    "/{resource_id}/lines/{line_id}",
    summary="Delete a line from a file-backed resource (204 No Content)",
    description="Delete a line from the resource. Returns 204 No Content on success.",
    status_code=204,
)
async def delete_resource_line(
    resource_id: Annotated[UUID, Path()],
    line_id: Annotated[int, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> None:
    resource = await _get_resource_if_accessable(resource_id, db, current_user)

    _enforce_editable(resource)
    await delete_resource_line_service(resource_id, line_id, db)


@router.get(
    "/{resource_id}/lines/validate",
    summary="Validate all lines in a file-backed resource (JSON, batch validation)",
    description="Return a JSON list of ResourceLineValidationError for all invalid lines in the resource. Returns 204 No Content if all lines are valid.",
)
async def validate_resource_lines(
    resource_id: Annotated[UUID, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> dict[str, object] | None:
    resource = await _get_resource_if_accessable(resource_id, db, current_user)

    if resource.resource_type not in EDITABLE_RESOURCE_TYPES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Resource type not editable."
        )

    await check_resource_editable(resource)
    errors = await validate_resource_lines_service(resource_id, db)
    if not errors:
        return None
    return {"errors": [e.model_dump(mode="json") for e in errors]}


@router.get(
    "/",
    summary="List all resources (paginated, filterable)",
    description="Return a paginated, filterable list of all resources for the resource browser.",
)
async def list_resources(
    db: Annotated[AsyncSession, Depends(get_db)],
    resource_type: AttackResourceType | None = None,
    q: str = "",
    page: int = 1,
    page_size: int = 25,
) -> ResourceListResponse:
    return await list_resources_service(
        db=db,
        resource_type=resource_type,
        q=q,
        page=page,
        page_size=page_size,
    )


@router.post(
    "/",
    summary="Upload metadata, request presigned upload URL",
    description="Create an AttackResourceFile DB record and return a presigned S3 upload URL. If upload fails, ensure no orphaned DB record remains.",
    status_code=201,
)
async def upload_resource_metadata(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    file_name: Annotated[str, Form(...)],
    resource_type: Annotated[str, Form(...)],
    project_id: Annotated[int | None, Form()] = None,
    description: Annotated[str | None, Form()] = None,
    tags: Annotated[str | None, Form()] = None,
) -> ResourceUploadResponse:
    # Validate resource_type
    try:
        resource_type_enum = AttackResourceType(resource_type)
    except ValueError as err:
        raise HTTPException(status_code=400, detail="Invalid resource_type") from err

    # Create DB record and presigned URL atomically
    try:
        if project_id and not (
            await user_can_access_project_by_id(current_user, project_id, db=db)
        ):
            raise HTTPException(
                status_code=403, detail="Not authorized for this project."
            )
        resource, presigned_url = await create_resource_and_presign_service(
            db=db,
            file_name=file_name,
            resource_type=resource_type_enum,
            project_id=project_id,
            description=description,
            tags=tags,
            user_id=current_user.id,
        )
    except RuntimeError as err:
        raise HTTPException(
            status_code=500, detail=f"Failed to create resource: {err}"
        ) from err
    return ResourceUploadResponse(
        resource_id=resource.id,
        presigned_url=presigned_url,
        resource=ResourceUploadMeta(
            file_name=resource.file_name,
            resource_type=resource.resource_type,
        ),
    )


@router.get(
    "/{resource_id}",
    summary="Get resource detail (metadata + linking)",
    description="Return resource metadata and all attacks using this resource.",
)
async def get_resource_detail(
    resource_id: Annotated[UUID, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ResourceDetailResponse:
    resource_model = await _get_resource_if_accessable(resource_id, db, current_user)
    from app.models.attack import Attack

    attack_models: list[Attack] = []
    if resource_model.resource_type == AttackResourceType.WORD_LIST:
        result = await db.execute(
            select(Attack).where(Attack.word_list_id == resource_id)
        )
        attack_models = list(result.scalars().all())
    attack_basics = [AttackBasic(id=a.id, name=a.name) for a in attack_models]

    return ResourceDetailResponse(
        id=resource_model.id,
        file_name=resource_model.file_name,
        resource_type=resource_model.resource_type,
        line_count=resource_model.line_count,
        byte_size=resource_model.byte_size,
        updated_at=resource_model.updated_at,
        attacks=attack_basics,
    )


@router.get(
    "/{resource_id}/preview",
    summary="Get a small content preview for a resource",
    description="Return the first few lines of the resource for preview purposes. Enforces project access.",
)
async def get_resource_preview(
    resource_id: Annotated[UUID, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ResourcePreviewResponse:
    resource_model = await _get_resource_if_accessable(resource_id, db, current_user)

    preview_lines = []
    preview_error = None
    max_preview_lines = 10
    if resource_model.content and "lines" in resource_model.content:
        lines = resource_model.content["lines"]
        if isinstance(lines, list):
            preview_lines = lines[:max_preview_lines]
        else:
            preview_error = "Resource lines are not a list."
    elif resource_model.resource_type not in [
        AttackResourceType.WORD_LIST,
        AttackResourceType.RULE_LIST,
        AttackResourceType.MASK_LIST,
        AttackResourceType.CHARSET,
        AttackResourceType.EPHEMERAL_WORD_LIST,
        AttackResourceType.EPHEMERAL_MASK_LIST,
        AttackResourceType.EPHEMERAL_RULE_LIST,
    ]:
        preview_error = "No preview available for this resource type."
    else:
        preview_error = "No preview available for this resource type."

    return ResourcePreviewResponse(
        id=resource_model.id,
        file_name=resource_model.file_name,
        resource_type=resource_model.resource_type,
        line_count=resource_model.line_count,
        byte_size=resource_model.byte_size,
        updated_at=resource_model.updated_at,
        preview_lines=preview_lines,
        preview_error=preview_error,
        max_preview_lines=max_preview_lines,
    )
