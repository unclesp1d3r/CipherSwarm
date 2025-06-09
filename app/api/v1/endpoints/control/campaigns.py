"""
Control API campaigns endpoints.

The Control API uses API key authentication and offset-based pagination.
All responses are JSON format.
Error responses must follow RFC9457 format.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.control_exceptions import InternalServerError, ProjectAccessDeniedError
from app.core.deps import get_current_control_user
from app.core.services.campaign_service import list_campaigns_service
from app.db.session import get_db
from app.models.user import User
from app.schemas.campaign import CampaignRead
from app.schemas.shared import OffsetPaginatedResponse

router = APIRouter(prefix="/campaigns", tags=["Control - Campaigns"])


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
) -> OffsetPaginatedResponse[CampaignRead]:
    """
    List campaigns with offset-based pagination and filtering.

    Access is scoped to projects the user has access to. If project_id is specified,
    the user must have access to that specific project.

    TODO: Implement API key authentication as specified in the Control API requirements.
    TODO: Add RFC9457 error handling for Control API compliance.
    """
    try:
        # Get user's accessible projects - inline logic instead of importing control_access
        accessible_projects = (
            [assoc.project_id for assoc in current_user.project_associations]
            if current_user.project_associations
            else []
        )

        if not accessible_projects:
            raise ProjectAccessDeniedError(detail="User has no project access")

        # If project_id is specified, check if user has access to it
        if project_id is not None:
            if project_id not in accessible_projects:
                raise ProjectAccessDeniedError(
                    detail=f"User does not have access to project {project_id}"
                )
            # Use single project_id for filtering
            campaigns, total = await list_campaigns_service(
                db=db,
                skip=offset,
                limit=limit,
                name_filter=name,
                project_id=project_id,
            )
        else:
            # Use multiple project_ids for filtering (much more efficient)
            campaigns, total = await list_campaigns_service(
                db=db,
                skip=offset,
                limit=limit,
                name_filter=name,
                project_ids=accessible_projects,
            )

        # Convert to offset-based paginated response format
        return OffsetPaginatedResponse(
            items=campaigns,
            total=total,
            limit=limit,
            offset=offset,
        )
    except ProjectAccessDeniedError:
        raise  # Re-raise project access errors
    except Exception as e:
        raise InternalServerError(detail=f"Failed to list campaigns: {e!s}") from e
