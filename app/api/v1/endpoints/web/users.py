from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.authz import user_can
from app.core.deps import get_current_user, get_db
from app.core.services.user_service import list_users_service
from app.models.user import User
from app.schemas.user import UserListItem

router = APIRouter(prefix="/users", tags=["Users"])


@router.get("", summary="List users")
async def list_users(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> list[UserListItem]:
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "read_users")
    ):
        raise HTTPException(status_code=403, detail="Not authorized")
    return await list_users_service(db)
