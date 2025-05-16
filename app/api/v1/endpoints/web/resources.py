from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.resource_service import (
    get_resource_content_service,
    list_rulelists_service,
    list_wordlists_service,
)
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
