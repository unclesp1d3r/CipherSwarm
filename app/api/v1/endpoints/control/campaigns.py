"""
Control API campaigns endpoints.

The Control API uses API key authentication and offset-based pagination.
All responses must be JSON by default, with optional MsgPack support.
Error responses must follow RFC9457 format.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_control_user
from app.core.services.campaign_service import list_campaigns_service
from app.db.session import get_db
from app.models.user import User
from app.schemas.campaign import CampaignRead

router = APIRouter(prefix="/campaigns", tags=["Control - Campaigns"])


class CampaignListPagination(BaseModel):
    """Offset-based pagination response for campaigns."""

    items: list[CampaignRead]
    total: int
    limit: int
    offset: int


@router.get(
    "",
    summary="List campaigns",
    description="List campaigns with offset-based pagination and filtering. Supports project scoping based on user permissions.",
)
async def list_campaigns(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_control_user)],
    limit: Annotated[
        int, Query(ge=1, le=100, description="Number of items to return")
    ] = 10,
    offset: Annotated[int, Query(ge=0, description="Number of items to skip")] = 0,
    name: Annotated[
        str | None,
        Query(description="Filter campaigns by name (case-insensitive partial match)"),
    ] = None,
    project_id: Annotated[
        int | None, Query(description="Filter campaigns by project ID")
    ] = None,
) -> CampaignListPagination:
    """
    List campaigns with offset-based pagination and filtering.

    Access is scoped to projects the user has access to. If project_id is specified,
    the user must have access to that specific project.

    TODO: Implement API key authentication as specified in the Control API requirements.
    TODO: Add RFC9457 error handling for Control API compliance.
    """
    # TODO: Replace this with proper project scoping based on API key permissions
    # For now, use the first project the user has access to if no project_id specified
    if project_id is None:
        if not current_user.project_associations:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User has no project access",
            )
        # Use the first project the user has access to
        project_id = current_user.project_associations[0].project_id
    else:
        # Check if user has access to the specified project
        user_project_ids = {
            assoc.project_id for assoc in current_user.project_associations
        }
        if project_id not in user_project_ids:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"User does not have access to project {project_id}",
            )

    try:
        campaigns, total = await list_campaigns_service(
            db=db,
            skip=offset,
            limit=limit,
            name_filter=name,
            project_id=project_id,
        )

        return CampaignListPagination(
            items=campaigns,
            total=total,
            limit=limit,
            offset=offset,
        )
    except Exception as e:
        # TODO: Implement RFC9457 error format for Control API
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to list campaigns: {e!s}",
        ) from e
