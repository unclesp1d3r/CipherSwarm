import os
from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.templating import Jinja2Templates

from app.core.deps import get_db
from app.core.services.resource_service import (
    get_resource_content_service,
    list_wordlists_service,
)

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
    resource, content, error_message, status_code = await get_resource_content_service(
        resource_id, db
    )
    if error_message:
        return templates.TemplateResponse(
            "fragments/alert.html",
            {"request": request, "message": error_message},
            status_code=status_code,
        )
    return templates.TemplateResponse(
        "resources/content_fragment.html",
        {"request": request, "resource": resource, "content": content},
        status_code=status_code,
    )


@router.get(
    "/wordlists",
    response_class=HTMLResponse,
    summary="List all wordlist resources for dropdown",
    description="Return an HTML fragment with all wordlist resources, sorted by last modified, with search and entry count support.",
)
async def list_wordlists(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    q: str = "",
) -> HTMLResponse:
    wordlists = await list_wordlists_service(db, q)
    return templates.TemplateResponse(
        "resources/wordlist_dropdown_fragment.html",
        {"request": request, "wordlists": wordlists},
    )
