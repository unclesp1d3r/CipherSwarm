"""
Control API campaigns endpoints.

The Control API uses API key authentication and offset-based pagination.
All responses are JSON format.
Error responses must follow RFC9457 format.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.control_access import get_user_accessible_projects
from app.core.control_exceptions import InternalServerError, ProjectAccessDeniedError
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
    try:
        # Get user's accessible projects
        accessible_projects = get_user_accessible_projects(current_user)

        if not accessible_projects:
            raise ProjectAccessDeniedError(detail="User has no project access")

        # If project_id is specified, check if user has access to it
        if project_id is not None:
            if project_id not in accessible_projects:
                raise ProjectAccessDeniedError(
                    detail=f"User does not have access to project {project_id}"
                )
            # Filter to only the specified project
            accessible_projects = [project_id]

        # If project_id is specified, use it; otherwise use None to get all accessible projects
        # Note: The existing service only supports single project_id filtering
        # For multiple projects, we'll need to call the service multiple times or modify it
        if project_id is not None:
            campaigns, total = await list_campaigns_service(
                db=db,
                skip=offset,
                limit=limit,
                name_filter=name,
                project_id=project_id,
            )
        else:
            # For now, we'll get campaigns from all accessible projects by calling service multiple times
            # This is not optimal but works with existing service interface
            all_campaigns = []
            total_count = 0

            for proj_id in accessible_projects:
                proj_campaigns, proj_total = await list_campaigns_service(
                    db=db,
                    skip=0,  # Get all campaigns from each project
                    limit=1000,  # Large limit to get all
                    name_filter=name,
                    project_id=proj_id,
                )
                all_campaigns.extend(proj_campaigns)
                total_count += proj_total

            # Apply pagination to the combined results
            campaigns = all_campaigns[offset : offset + limit]
            total = total_count

        return CampaignListPagination(
            items=campaigns,
            total=total,
            limit=limit,
            offset=offset,
        )
    except ProjectAccessDeniedError:
        raise  # Re-raise project access errors
    except Exception as e:
        raise InternalServerError(detail=f"Failed to list campaigns: {e!s}") from e
