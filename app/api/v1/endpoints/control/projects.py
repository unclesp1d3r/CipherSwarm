from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.authz import user_can_access_project_by_id
from app.core.control_exceptions import (
    ProjectAccessDeniedError,
    ProjectNotFoundError,
)
from app.core.deps import get_current_control_user
from app.core.services.project_service import (
    ProjectNotFoundError as ServiceProjectNotFoundError,
)
from app.core.services.project_service import (
    create_project_service,
    delete_project_service,
    get_project_service,
    list_project_users_service,
    list_projects_service_offset,
    update_project_service,
)
from app.db.session import get_db
from app.models.user import User
from app.schemas.project import ProjectCreate, ProjectRead, ProjectUpdate
from app.schemas.shared import OffsetPaginatedResponse
from app.schemas.user import UserRead

router = APIRouter(prefix="/projects", tags=["Projects"])


class ProjectListResponse(OffsetPaginatedResponse[ProjectRead]):
    search: str | None = None


class ProjectUsersResponse(OffsetPaginatedResponse[UserRead]):
    pass


@router.get("", summary="List projects")
async def list_projects(
    current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    offset: Annotated[int, Query(ge=0, description="Number of records to skip")] = 0,
    limit: Annotated[
        int, Query(ge=1, le=100, description="Number of records to return")
    ] = 20,
) -> ProjectListResponse:
    """
    List projects accessible to the current user.

    Access is scoped to projects the user has access to based on their project associations.
    Superusers and admin users can see all projects, while regular users only see
    projects they are explicitly assigned to.
    """
    projects, total = await list_projects_service_offset(
        db=db, skip=offset, limit=limit, user=current_user
    )

    return ProjectListResponse(
        items=projects, total=total, limit=limit, offset=offset, search=None
    )


@router.get("/{project_id}", summary="Get project by ID")
async def get_project(
    project_id: int,
    current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ProjectRead:
    """Get project details by ID."""
    # Check access - provide specific error messages for administrators
    try:
        has_access = await user_can_access_project_by_id(
            current_user, project_id, db=db
        )

        if not has_access:
            raise ProjectAccessDeniedError(
                detail=f"User '{current_user.name}' does not have access to project {project_id}. Available projects: {[assoc.project_id for assoc in current_user.project_associations]}"
            )
    except ServiceProjectNotFoundError as err:
        # Project doesn't exist - provide clear message to administrators
        raise ProjectNotFoundError(
            detail=f"Project {project_id} not found in database"
        ) from err

    try:
        return await get_project_service(project_id=project_id, db=db)
    except ServiceProjectNotFoundError as err:
        raise ProjectNotFoundError(
            detail=f"Project {project_id} not found in database"
        ) from err


@router.post("", summary="Create project")
async def create_project(
    project_data: ProjectCreate,
    _current_user: Annotated[
        User, Depends(get_current_control_user)
    ],  # Prefix with _ since it's required but unused
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ProjectRead:
    """Create a new project."""
    return await create_project_service(data=project_data, db=db)


@router.patch("/{project_id}", summary="Update project")
async def update_project(
    project_id: int,
    project_data: ProjectUpdate,
    current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ProjectRead:
    """Update project by ID."""
    # Check access - provide specific error messages for administrators
    try:
        has_access = await user_can_access_project_by_id(
            current_user, project_id, db=db
        )
        if not has_access:
            raise ProjectAccessDeniedError(
                detail=f"User '{current_user.name}' does not have access to project {project_id}. Available projects: {[assoc.project_id for assoc in current_user.project_associations]}"
            )
    except ServiceProjectNotFoundError as err:
        # Project doesn't exist - provide clear message to administrators
        raise ProjectNotFoundError(
            detail=f"Project {project_id} not found in database"
        ) from err

    try:
        return await update_project_service(
            project_id=project_id, data=project_data, db=db
        )
    except ServiceProjectNotFoundError as err:
        raise ProjectNotFoundError(
            detail=f"Project {project_id} not found in database"
        ) from err


@router.delete("/{project_id}", summary="Delete project")
async def delete_project(
    project_id: int,
    current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
) -> Response:
    """Delete a project."""
    # Check access - provide specific error messages for administrators
    try:
        has_access = await user_can_access_project_by_id(
            current_user, project_id, db=db
        )
        if not has_access:
            raise ProjectAccessDeniedError(
                detail=f"User '{current_user.name}' does not have access to project {project_id}. Available projects: {[assoc.project_id for assoc in current_user.project_associations]}"
            )
    except ServiceProjectNotFoundError as err:
        # Project doesn't exist - provide clear message to administrators
        raise ProjectNotFoundError(
            detail=f"Project {project_id} not found in database"
        ) from err

    try:
        await delete_project_service(project_id=project_id, db=db)
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except ServiceProjectNotFoundError as err:
        raise ProjectNotFoundError(
            detail=f"Project {project_id} not found in database"
        ) from err


@router.get("/{project_id}/users", summary="List project users")
async def list_project_users(
    project_id: int,
    current_user: Annotated[User, Depends(get_current_control_user)],
    db: Annotated[AsyncSession, Depends(get_db)],
    offset: Annotated[int, Query(ge=0, description="Number of records to skip")] = 0,
    limit: Annotated[
        int, Query(ge=1, le=100, description="Number of records to return")
    ] = 20,
) -> ProjectUsersResponse:
    """
    List users associated with a specific project.

    Access is scoped to projects the user has access to based on their project associations.
    """
    # Check access - provide specific error messages for administrators
    try:
        has_access = await user_can_access_project_by_id(
            current_user, project_id, db=db
        )
        if not has_access:
            raise ProjectAccessDeniedError(
                detail=f"User '{current_user.name}' does not have access to project {project_id}. Available projects: {[assoc.project_id for assoc in current_user.project_associations]}"
            )
    except ServiceProjectNotFoundError as err:
        # Project doesn't exist - provide clear message to administrators
        raise ProjectNotFoundError(
            detail=f"Project {project_id} not found in database"
        ) from err

    try:
        users, total = await list_project_users_service(
            project_id=project_id, db=db, offset=offset, limit=limit
        )
        return ProjectUsersResponse(
            items=users, total=total, limit=limit, offset=offset
        )
    except ServiceProjectNotFoundError as err:
        raise ProjectNotFoundError(
            detail=f"Project {project_id} not found in database"
        ) from err
