from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.exc import NoResultFound
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.authz import user_can
from app.core.deps import get_current_user, get_db
from app.core.services.user_service import (
    create_user_service,
    deactivate_user_service,
    get_user_by_id_service,
    list_users_paginated_service,
    update_user_service,
)
from app.models.user import User
from app.schemas.user import UserCreate, UserRead, UserUpdate
from app.web.templates import jinja

router = APIRouter(
    prefix="/users",
    tags=["Users"],
)

"""
Rules to follow:
1. Use @jinja.page() with a Pydantic return model
2. DO NOT use TemplateResponse or return dicts - absolutely avoid dict[str, object]
3. DO NOT put database logic here — call user_service
4. Extract all context from DI dependencies, not request.query_params
5. Follow FastAPI idiomatic parameter usage
6. user_can() is available and implemented, so stop adding TODO items
"""


@router.get("")
@router.get("/")
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


class UserCreateResponse(BaseModel):
    success: bool
    user: UserRead | None = None
    error: str | None = None
    form: UserCreate | None = None


@router.post("")
@router.post("/")
@jinja.page("users/create_form.html.j2")
async def create_user(
    user_in: UserCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> UserCreateResponse:
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "create_users")
    ):
        raise HTTPException(status_code=403, detail="Not authorized")
    try:
        user = await create_user_service(db, user_in)
    except ValueError as e:
        return UserCreateResponse(success=False, error=str(e), form=user_in, user=None)
    return UserCreateResponse(success=True, user=user, form=None, error=None)


@router.get(
    "/{user_id}",
    summary="View user detail",
    description="Admin-only: View user detail as an HTML fragment.",
)
@jinja.page("users/detail.html.j2")
async def get_user_detail(
    user_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> dict[str, object]:
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "read_users")
    ):
        raise HTTPException(status_code=403, detail="Not authorized")
    try:
        user = await get_user_by_id_service(db, user_id)
    except NoResultFound:
        raise HTTPException(status_code=404, detail="User not found") from None
    return {"user": user}


@router.patch(
    "/{user_id}",
    summary="Update user info or role",
    description="Admin-only: Update user info or role. Returns updated user detail fragment.",
)
@jinja.hx("users/detail.html.j2")
async def update_user(
    user_id: UUID,
    payload: UserUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> dict[str, object]:
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "update_users")
    ):
        raise HTTPException(status_code=403, detail="Not authorized")
    try:
        user = await update_user_service(db, user_id, payload)
    except NoResultFound:
        raise HTTPException(status_code=404, detail="User not found") from None
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e)) from None
    return {"user": user}


@router.delete(
    "/{user_id}",
    summary="Deactivate (soft delete) a user",
    description="Admin-only: Deactivate (soft delete) a user. Returns updated user detail fragment.",
)
@jinja.page("users/detail.html.j2")
async def deactivate_user(
    user_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> dict[str, object]:
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "delete_users")
    ):
        raise HTTPException(status_code=403, detail="Not authorized")
    try:
        user = await deactivate_user_service(db, user_id)
    except NoResultFound:
        raise HTTPException(status_code=404, detail="User not found") from None
    return {"user": user}
