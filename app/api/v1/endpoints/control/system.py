from typing import Annotated

from cashews import cache
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.deps import get_current_control_user
from app.core.services.dashboard_service import get_dashboard_summary_service
from app.core.services.health_service import get_system_health_overview_service
from app.core.services.queue_service import get_queue_status_service
from app.db.session import get_db
from app.models.user import User
from app.schemas.health import SystemHealthOverview
from app.schemas.queue import QueueStatusResponse
from app.schemas.shared import DashboardSummary

router = APIRouter(prefix="/system", tags=["System"])


class SystemVersionResponse(BaseModel):
    """System version information."""

    version: str = Field(..., description="Current system version")
    project_name: str = Field(..., description="Project name")


@router.get("/status", summary="Get system health status")
async def get_system_status(
    current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> SystemHealthOverview:
    """Get system health status for monitoring and troubleshooting."""
    return await get_system_health_overview_service(db, current_user)


@router.get("/stats", summary="Get system statistics")
async def get_system_stats(
    _current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> DashboardSummary:
    """Get system-wide statistics and metrics."""
    return await get_dashboard_summary_service(db)


@router.get("/queues", summary="Get queue status")
async def get_queue_status(
    _current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> QueueStatusResponse:
    """Get queue status and background task monitoring information."""
    return await get_queue_status_service(db)


@router.get("/version", summary="Get system version")
@cache(ttl="30m", key="system_version")
async def get_system_version(
    _current_user: Annotated[User, Depends(get_current_control_user)],
) -> SystemVersionResponse:
    """Get system version information for compatibility checking."""
    return SystemVersionResponse(
        version=settings.VERSION,
        project_name=settings.PROJECT_NAME,
    )
