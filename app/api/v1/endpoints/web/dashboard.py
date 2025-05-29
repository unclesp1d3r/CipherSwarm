from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.services.dashboard_service import get_dashboard_summary_service
from app.db.session import get_db
from app.schemas.shared import DashboardSummary

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


@router.get("/summary", status_code=status.HTTP_200_OK)
async def get_dashboard_summary(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> DashboardSummary:
    return await get_dashboard_summary_service(db)
