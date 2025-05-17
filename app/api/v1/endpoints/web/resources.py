from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Body, Depends, HTTPException, Path, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.deps import get_db
from app.core.services.resource_service import (
    add_resource_line_service,
    delete_resource_line_service,
    get_resource_content_service,
    get_resource_lines_service,
    list_rulelists_service,
    list_wordlists_service,
    update_resource_line_service,
    validate_resource_lines_service,
)
from app.models.attack_resource_file import AttackResourceFile, AttackResourceType
from app.web.templates import jinja

router = APIRouter(prefix="/resources", tags=["Resources"])


@router.get(
    "/{resource_id}/content",
    summary="Get raw editable text content for a resource",
    description="Return an HTML fragment with the raw text content for eligible resources (mask, rule, wordlist, charset). Enforces editability constraints.",
)
@jinja.page("resources/content_fragment.html.j2")
async def get_resource_content(
    resource_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, object]:
    resource, content, error_message, status_code = await get_resource_content_service(
        resource_id, db
    )
    if error_message:
        raise HTTPException(status_code=status_code, detail=error_message)
    resource_dict: dict[str, object] = {}
    if resource is not None:
        resource_dict = {
            "id": str(resource.id),
            "file_name": resource.file_name,
            "resource_type": resource.resource_type,
            "line_count": resource.line_count,
            "byte_size": resource.byte_size,
            "updated_at": resource.updated_at,
        }
    return {"resource": resource_dict, "content": content}


@router.get(
    "/wordlists",
    summary="List all wordlist resources for dropdown",
    description="Return an HTML fragment with all wordlist resources, sorted by last modified, with search and entry count support.",
)
@jinja.page("resources/wordlist_dropdown_fragment.html.j2")
async def list_wordlists(
    db: Annotated[AsyncSession, Depends(get_db)],
    q: str = "",
) -> dict[str, object]:
    wordlists = await list_wordlists_service(db, q)
    return {"wordlists": wordlists}


@router.get(
    "/rulelists",
    summary="List all rule list resources for dropdown",
    description="Return an HTML fragment with all rule list resources, sorted by last modified, with search and entry count support.",
)
@jinja.page("resources/rulelist_dropdown_fragment.html.j2")
async def list_rulelists(
    db: Annotated[AsyncSession, Depends(get_db)],
    q: str = "",
) -> dict[str, object]:
    rulelists = await list_rulelists_service(db, q)
    return {"rulelists": rulelists}


# Helper dependency to get resource type
async def get_resource_type(
    resource_id: UUID, db: AsyncSession = Depends(get_db)
) -> str:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    return resource.resource_type


def is_ephemeral_resource_type(resource_type: str) -> bool:
    return resource_type in {
        AttackResourceType.EPHEMERAL_WORD_LIST,
        AttackResourceType.EPHEMERAL_MASK_LIST,
        AttackResourceType.EPHEMERAL_RULE_LIST,
    }


# --- Resource Line-Oriented Editing (File-Backed Only) ---

EDITABLE_RESOURCE_TYPES = {
    AttackResourceType.MASK_LIST,
    AttackResourceType.RULE_LIST,
    AttackResourceType.WORD_LIST,
    AttackResourceType.CHARSET,
}


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


@router.get(
    "/{resource_id}/lines",
    summary="List lines in a file-backed resource (HTML fragment, paginated, optionally validated)",
    description="Return a paginated list of lines in the resource as an HTML fragment for in-browser editing. Supports ?validate=true for batch validation.",
)
@jinja.page("resources/lines_fragment.html.j2")
async def list_resource_lines(
    resource_id: Annotated[UUID, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    page: int = 1,
    page_size: int = 100,
) -> dict[str, object]:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    if resource.resource_type in {
        AttackResourceType.EPHEMERAL_WORD_LIST,
        AttackResourceType.EPHEMERAL_MASK_LIST,
        AttackResourceType.EPHEMERAL_RULE_LIST,
    }:
        raise HTTPException(
            status_code=403,
            detail="Ephemeral resources are not editable via this endpoint.",
        )
    lines = await get_resource_lines_service(resource_id, db, page, page_size)
    return {"lines": lines, "resource_id": resource_id}


@router.post(
    "/{resource_id}/lines",
    summary="Add a new line to a file-backed resource (204 No Content)",
    description="Add a new line to the resource. Returns 204 No Content on success, 422 JSON on validation error.",
    status_code=204,
)
async def add_resource_line(
    resource_id: Annotated[UUID, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
    line: Annotated[str, Body(embed=True, description="Line content to add")],
) -> None:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    if resource.resource_type in {
        AttackResourceType.EPHEMERAL_WORD_LIST,
        AttackResourceType.EPHEMERAL_MASK_LIST,
        AttackResourceType.EPHEMERAL_RULE_LIST,
    }:
        raise HTTPException(
            status_code=403,
            detail="Ephemeral resources are not editable via this endpoint.",
        )
    try:
        await add_resource_line_service(resource_id, db, line)
    except HTTPException as exc:
        if exc.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY:
            raise
        raise


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
    line: Annotated[str, Body(embed=True, description="New line content")],
) -> None:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    if resource.resource_type in {
        AttackResourceType.EPHEMERAL_WORD_LIST,
        AttackResourceType.EPHEMERAL_MASK_LIST,
        AttackResourceType.EPHEMERAL_RULE_LIST,
    }:
        raise HTTPException(
            status_code=403,
            detail="Ephemeral resources are not editable via this endpoint.",
        )
    try:
        await update_resource_line_service(resource_id, line_id, db, line)
    except HTTPException as exc:
        if exc.status_code == status.HTTP_422_UNPROCESSABLE_ENTITY:
            raise
        raise


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
) -> None:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    if resource.resource_type in {
        AttackResourceType.EPHEMERAL_WORD_LIST,
        AttackResourceType.EPHEMERAL_MASK_LIST,
        AttackResourceType.EPHEMERAL_RULE_LIST,
    }:
        raise HTTPException(
            status_code=403,
            detail="Ephemeral resources are not editable via this endpoint.",
        )
    await delete_resource_line_service(resource_id, line_id, db)


@router.get(
    "/{resource_id}/lines/validate",
    summary="Validate all lines in a file-backed resource (JSON, batch validation)",
    description="Return a JSON list of ResourceLineValidationError for all invalid lines in the resource. Returns 204 No Content if all lines are valid.",
    response_model=None,
)
async def validate_resource_lines(
    resource_id: Annotated[UUID, Path()],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response | dict[str, object]:
    errors = await validate_resource_lines_service(resource_id, db)
    if not errors:
        return Response(status_code=204)
    return {"errors": [e.model_dump(mode="json") for e in errors]}
