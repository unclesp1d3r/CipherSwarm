from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.project_service import (
    ProjectNotFoundError,
    create_project_service,
    delete_project_service,
    get_project_service,
    update_project_service,
)
from app.schemas.project import ProjectCreate, ProjectRead, ProjectUpdate

router = APIRouter(prefix="/projects", tags=["Projects"])


# /api/v1/web/projects/{project_id}
@router.get(
    "/{project_id}",
    summary="Get project",
    description="Get a project by ID.",
    responses={status.HTTP_404_NOT_FOUND: {"description": "Project not found"}},
)
async def get_project(
    project_id: int, db: Annotated[AsyncSession, Depends(get_db)]
) -> ProjectRead:
    try:
        return await get_project_service(project_id, db)
    except ProjectNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


# /api/v1/web/projects
@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    summary="Create project",
    description="Create a new project.",
)
async def create_project(
    data: ProjectCreate, db: Annotated[AsyncSession, Depends(get_db)]
) -> ProjectRead:
    return await create_project_service(data, db)


# /api/v1/web/projects/{project_id}
@router.put(
    "/{project_id}",
    summary="Update project",
    description="Update a project by ID.",
    responses={status.HTTP_404_NOT_FOUND: {"description": "Project not found"}},
)
async def update_project(
    project_id: int,
    data: ProjectUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ProjectRead:
    try:
        return await update_project_service(project_id, data, db)
    except ProjectNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


# /api/v1/web/projects/{project_id}
@router.delete(
    "/{project_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete project",
    description="Delete a project by ID.",
    responses={status.HTTP_404_NOT_FOUND: {"description": "Project not found"}},
)
async def delete_project(
    project_id: int, db: Annotated[AsyncSession, Depends(get_db)]
) -> None:
    try:
        await delete_project_service(project_id, db)
    except ProjectNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
