from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.project_service import (
    ProjectNotFoundError,
    create_project_service,
    delete_project_service,
    get_project_service,
    list_projects_service,
    update_project_service,
)
from app.schemas.project import ProjectCreate, ProjectRead, ProjectUpdate

router = APIRouter()


@router.get(
    "/",
    summary="List campaigns",
    description="List all campaigns (projects).",
    tags=["Campaigns"],
)
async def list_campaigns(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> list[ProjectRead]:
    return await list_projects_service(db)


@router.get(
    "/{project_id}",
    summary="Get campaign",
    description="Get a campaign (project) by ID.",
    tags=["Campaigns"],
    responses={404: {"description": "Campaign not found"}},
)
async def get_campaign(
    project_id: UUID, db: Annotated[AsyncSession, Depends(get_db)]
) -> ProjectRead:
    try:
        return await get_project_service(project_id, db)
    except ProjectNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.post(
    "/",
    status_code=status.HTTP_201_CREATED,
    summary="Create campaign",
    description="Create a new campaign (project).",
    tags=["Campaigns"],
)
async def create_campaign(
    data: ProjectCreate, db: Annotated[AsyncSession, Depends(get_db)]
) -> ProjectRead:
    return await create_project_service(data, db)


@router.put(
    "/{project_id}",
    summary="Update campaign",
    description="Update a campaign (project) by ID.",
    tags=["Campaigns"],
    responses={404: {"description": "Campaign not found"}},
)
async def update_campaign(
    project_id: UUID,
    data: ProjectUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
) -> ProjectRead:
    try:
        return await update_project_service(project_id, data, db)
    except ProjectNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


@router.delete(
    "/{project_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete campaign",
    description="Delete a campaign (project) by ID.",
    tags=["Campaigns"],
    responses={404: {"description": "Campaign not found"}},
)
async def delete_campaign(
    project_id: UUID, db: Annotated[AsyncSession, Depends(get_db)]
) -> None:
    try:
        await delete_project_service(project_id, db)
    except ProjectNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
