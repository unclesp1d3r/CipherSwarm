from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_control_user
from app.core.services.dashboard_service import get_dashboard_summary_service
from app.core.services.health_service import get_system_health_overview_service
from app.db.session import get_db
from app.models.user import User
from app.schemas.health import SystemHealthOverview
from app.schemas.shared import DashboardSummary

router = APIRouter(prefix="/system", tags=["System"])


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
