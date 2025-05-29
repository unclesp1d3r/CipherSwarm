from collections.abc import Callable
from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user, get_db
from app.core.services.health_service import get_system_health_overview_service
from app.core.services.storage_service import StorageService, get_storage_service
from app.models.user import User
from app.schemas.health import SystemHealthOverview

router = APIRouter(prefix="/health", tags=["Health"])


def get_storage_service_dep() -> Callable[[], StorageService]:
    return get_storage_service


@router.get("/overview", status_code=status.HTTP_200_OK)
async def get_system_health_overview(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    get_storage_service_fn: Annotated[
        Callable[[], StorageService], Depends(get_storage_service_dep)
    ],
) -> SystemHealthOverview:
    return await get_system_health_overview_service(
        db, current_user, get_storage_service_fn
    )
