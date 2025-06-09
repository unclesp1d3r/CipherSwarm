from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.endpoints.control.utils import control_to_web_pagination
from app.core.control_access import require_project_access
from app.core.deps import get_current_control_user
from app.core.services.project_service import (
    create_project_service,
    delete_project_service,
    get_project_service,
    list_projects_service,
    update_project_service,
)
from app.db.session import get_db
from app.models.user import User
from app.schemas.project import ProjectCreate, ProjectRead, ProjectUpdate
from app.schemas.shared import PaginatedResponse

router = APIRouter(prefix="/projects", tags=["Projects"])


@router.get("/", summary="List projects")
async def list_projects(
    current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    offset: Annotated[int, Query(ge=0, description="Number of records to skip")] = 0,
    limit: Annotated[
        int, Query(ge=1, le=100, description="Number of records to return")
    ] = 20,
) -> PaginatedResponse[ProjectRead]:
    """
    List projects accessible to the current user.

    Access is scoped to projects the user has access to based on their project associations.
    Superusers and admin users can see all projects, while regular users only see
    projects they are explicitly assigned to.
    """
    # Check that user has access to at least some projects
    await require_project_access(current_user)

    page, page_size = control_to_web_pagination(offset, limit)
    projects, total = await list_projects_service(
        db=db, page=page, page_size=page_size, user=current_user
    )
    return PaginatedResponse(
        items=projects, total=total, page=page, page_size=page_size
    )


@router.get("/{project_id}", summary="Get project details")
async def get_project(
    project_id: int,
    _current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ProjectRead:
    """Get detailed information about a specific project."""
    return await get_project_service(project_id=project_id, db=db)


@router.post("/", summary="Create project")
async def create_project(
    project_data: ProjectCreate,
    _current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ProjectRead:
    """Create a new project."""
    return await create_project_service(data=project_data, db=db)


@router.patch("/{project_id}", summary="Update project")
async def update_project(
    project_id: int,
    project_data: ProjectUpdate,
    _current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ProjectRead:
    """Update an existing project."""
    return await update_project_service(project_id=project_id, data=project_data, db=db)


@router.delete("/{project_id}", summary="Delete project")
async def delete_project(
    project_id: int,
    _current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> dict[str, str]:
    """Delete a project."""
    await delete_project_service(project_id=project_id, db=db)
    return {"message": "Project deleted successfully"}
