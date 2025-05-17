from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.authz import user_can
from app.core.deps import get_current_user, get_db
from app.core.services.user_service import list_users_paginated_service
from app.models.user import User
from app.web.templates import jinja

router = APIRouter(prefix="/users", tags=["Users"])


@router.get(
    "",
    summary="List all users (paginated, filterable)",
    description="Admin-only: Returns a paginated, filterable list of all users as an HTML fragment for the Flowbite table UI.",
)
@jinja.page("users/list.html.j2")
async def list_users(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    page: Annotated[int, Query(ge=1, description="Page number")] = 1,
    page_size: Annotated[int, Query(ge=1, le=100, description="Users per page")] = 20,
    search: Annotated[str | None, Query(description="Search by name or email")] = None,
) -> dict[str, object]:
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "read_users")
    ):
        raise HTTPException(status_code=403, detail="Not authorized")
    result = await list_users_paginated_service(
        db, page=page, page_size=page_size, search=search
    )
    return {
        "users": result.users,
        "total": result.total,
        "page": page,
        "page_size": page_size,
        "search": search,
    }
