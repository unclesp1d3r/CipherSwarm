"""
🧭 JSON API Refactor – CipherSwarm Web UI

Follow these rules for all endpoints in this file:
1. Must return Pydantic models as JSON (no TemplateResponse or render()).
2. Must use FastAPI parameter types: Query, Path, Body, Depends, etc.
3. Must not parse inputs manually — let FastAPI validate and raise 422s.
4. Must use dependency-injected context for auth/user/project state.
5. Must not include database logic — delegate to a service layer (e.g. campaign_service).
6. Must not contain HTMX, Jinja, or fragment-rendering logic.
7. Must annotate live-update triggers with: # WS_TRIGGER: <event description>
8. Must update test files to expect JSON (not HTML) and preserve test coverage.

📘 See canonical task list and instructions:
↪️  docs/v2_rewrite_implementation_plan/side_quests/web_api_json_tasks.md
"""

from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.authz import user_can
from app.core.deps import get_current_user, get_db
from app.core.services.project_service import (
    ProjectNotFoundError,
    create_project_service,
    delete_project_service,
    get_project_service,
    list_projects_service,
    update_project_service,
)
from app.models.user import User
from app.schemas.project import ProjectCreate, ProjectRead, ProjectUpdate
from app.web.templates import jinja

router = APIRouter(prefix="/projects", tags=["Projects"])


# /api/v1/web/projects/{project_id}
@router.get(
    "/{project_id}",
    summary="Get project info",
    description="Get a project by ID and return an HTML fragment for the project info modal.",
)
@jinja.hx("projects/project_info.html.j2")
async def get_project(
    project_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> dict[str, object]:
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "read_projects")
    ):
        raise HTTPException(status_code=403, detail="Not authorized")
    try:
        project = await get_project_service(project_id, db)
    except ProjectNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    return {"project": project}


# /api/v1/web/projects
@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    summary="Create project",
    description="Create a new project. Only admins can create projects.",
)
async def create_project(
    data: ProjectCreate,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> ProjectRead:
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "create_projects")
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to create projects",
        )
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
    summary="Archive (soft delete) project",
    description="Archive a project by ID (soft delete). Only admins can archive projects. Sets archived_at timestamp.",
    responses={status.HTTP_404_NOT_FOUND: {"description": "Project not found"}},
)
async def delete_project(
    project_id: int,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> None:
    # Soft delete (archive) per implementation guide
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "delete_projects")
    ):
        raise HTTPException(status_code=403, detail="Not authorized")
    try:
        await delete_project_service(project_id, db)
    except ProjectNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e


# /api/v1/web/projects
@router.get("")
@jinja.page("projects/list.html.j2")
async def list_projects(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    page: Annotated[int, Query(ge=1, description="Page number")] = 1,
    page_size: Annotated[
        int, Query(ge=1, le=100, description="Projects per page")
    ] = 20,
    search: Annotated[
        str | None, Query(description="Search by name or description")
    ] = None,
) -> dict[str, object]:
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "read_projects")
    ):
        raise HTTPException(status_code=403, detail="Not authorized")
    projects, total = await list_projects_service(
        db, search=search, page=page, page_size=page_size
    )
    return {
        "projects": projects,
        "total": total,
        "page": page,
        "page_size": page_size,
        "search": search,
    }


# /api/v1/web/projects/{project_id}
@router.patch(
    "/{project_id}",
    summary="Update project (partial)",
    description="Update project fields (name, visibility, user assignment, etc). Admin-only. Returns updated project info fragment.",
)
@jinja.hx("projects/project_info.html.j2")
async def patch_project(
    project_id: int,
    data: ProjectUpdate,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> dict[str, object]:
    if not (
        getattr(current_user, "is_superuser", False)
        or user_can(current_user, "system", "update_projects")
    ):
        raise HTTPException(status_code=403, detail="Not authorized")
    try:
        project = await update_project_service(project_id, data, db)
    except ProjectNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
    return {"project": project}
