from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.authz import user_can
from app.core.deps import get_current_user, get_db
from app.models.user import User


class UserListItem(BaseModel):
    username: str
    email: str
    is_active: bool


users_router = APIRouter(prefix="/users", tags=["Users"])


@users_router.get("", summary="List users")
async def list_users(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> list[UserListItem]:
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "read_users")
    ):
        raise HTTPException(status_code=403, detail="Not authorized")
    result = await db.execute(select(User))
    users = result.scalars().all()
    return [
        UserListItem(username=u.name, email=u.email, is_active=u.is_active)
        for u in users
    ]
