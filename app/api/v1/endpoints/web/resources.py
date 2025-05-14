import os
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from loguru import logger
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.templating import Jinja2Templates

from app.core.deps import get_db
from app.models.attack_resource_file import AttackResourceFile, AttackResourceType

router = APIRouter(prefix="/resources", tags=["Resources"])

templates = Jinja2Templates(directory="templates")


# Configurable editability thresholds
def get_editability_limits() -> tuple[int, int]:
    max_lines = int(os.getenv("RESOURCE_EDIT_MAX_LINES", "5000"))
    max_bytes = int(os.getenv("RESOURCE_EDIT_MAX_SIZE_MB", "1")) * 1024 * 1024
    return max_lines, max_bytes


@router.get(
    "/{resource_id}/content",
    response_class=HTMLResponse,
    summary="Get raw editable text content for a resource",
    description="Return an HTML fragment with the raw text content for eligible resources (mask, rule, wordlist, charset). Enforces editability constraints.",
)
async def get_resource_content(
    request: Request,
    resource_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> HTMLResponse:
    # Fetch resource
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        logger.warning(f"Resource not found: {resource_id}")
        raise HTTPException(status_code=404, detail="Resource not found")

    # Enforce editability constraints
    max_lines, max_bytes = get_editability_limits()
    if resource.resource_type == AttackResourceType.DYNAMIC_WORD_LIST:
        logger.info(f"Resource {resource_id} is not editable (dynamic word list)")
        return templates.TemplateResponse(
            "fragments/alert.html",
            {
                "request": request,
                "message": "This resource is read-only and cannot be edited inline.",
            },
            status_code=403,
        )
    if resource.line_count > max_lines or resource.byte_size > max_bytes:
        logger.info(
            f"Resource {resource_id} exceeds editability limits: {resource.line_count} lines, {resource.byte_size} bytes"
        )
        return templates.TemplateResponse(
            "fragments/alert.html",
            {
                "request": request,
                "message": f"This resource is too large to edit inline (max {max_lines} lines, {max_bytes // 1024 // 1024}MB). Download and edit offline.",
            },
            status_code=403,
        )
    # Only allow editable types
    if resource.resource_type not in {
        AttackResourceType.MASK_LIST,
        AttackResourceType.RULE_LIST,
        AttackResourceType.WORD_LIST,
        AttackResourceType.CHARSET,
    }:
        logger.info(
            f"Resource {resource_id} is not an editable type: {resource.resource_type}"
        )
        return templates.TemplateResponse(
            "fragments/alert.html",
            {
                "request": request,
                "message": "This resource type cannot be edited inline.",
            },
            status_code=403,
        )
    # Load content from storage (stub: replace with actual S3 or file backend)
    # For now, just return a placeholder or fake content
    # TODO: Integrate with MinIO or file backend to fetch actual content
    fake_content = (
        f"# Resource: {resource.file_name}\n# (Replace with actual file content)\n"
    )
    return templates.TemplateResponse(
        "resources/content_fragment.html",
        {"request": request, "resource": resource, "content": fake_content},
    )
