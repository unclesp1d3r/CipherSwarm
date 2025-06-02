import pathlib
import re
from typing import Annotated

from fastapi import APIRouter, Depends, Form, HTTPException, Path, Query, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.deps import get_current_user
from app.core.logging import logger
from app.core.services.resource_service import (
    create_upload_resource_and_task_service,
    get_upload_errors_service,
    get_upload_status_service,
)
from app.db.session import get_db
from app.models.project import Project, ProjectUserAssociation
from app.models.user import User
from app.schemas.resource import (
    ResourceUploadMeta,
    ResourceUploadResponse,
    UploadErrorEntryListResponse,
    UploadStatusOut,
)

router = APIRouter(prefix="/uploads", tags=["Uploads"])

ALLOWED_EXTENSIONS = {".shadow", ".pdf", ".zip", ".7z", ".docx"}
FILENAME_REGEX = re.compile(r"^[\w,\s-]+\.[A-Za-z0-9]{1,8}$")  # Basic filename check


def validate_upload_filename(filename: str) -> None:
    ext = pathlib.Path(filename).suffix.lower()
    if ext not in ALLOWED_EXTENSIONS:
        logger.warning(
            f"File extension '{ext}' is not allowed. Allowed: {', '.join(ALLOWED_EXTENSIONS)}",
        )
        raise HTTPException(
            status_code=400,
            detail=f"File extension '{ext}' is not allowed. Allowed: {', '.join(ALLOWED_EXTENSIONS)}",
        )
    if not FILENAME_REGEX.match(filename):
        logger.warning(
            f"File name '{filename}' does not match regex {FILENAME_REGEX.pattern}",
        )
        raise HTTPException(
            status_code=400,
            detail="Invalid file name. Only alphanumeric, dash, underscore, space, and a single extension are allowed.",
        )


def validate_upload_size(request: Request) -> None:
    max_size = settings.UPLOAD_MAX_SIZE
    content_length = request.headers.get("content-length")
    if content_length is not None:
        try:
            size = int(content_length)
        except ValueError as e:
            logger.exception(f"Invalid Content-Length header: {e}")
            raise HTTPException(
                status_code=400, detail="Invalid Content-Length header."
            ) from e
        if size > max_size:
            logger.warning(
                f"Upload size exceeds maximum allowed ({max_size // (1024 * 1024)}MB).",
            )
            raise HTTPException(
                status_code=400,
                detail=f"Upload size exceeds maximum allowed ({max_size // (1024 * 1024)}MB).",
            )


@router.post(
    "/",
    summary="Upload metadata, request presigned upload URL for UploadResourceFile",
    description="Create an UploadResourceFile DB record, a HashUploadTask, and return a presigned S3 upload URL. If upload fails, ensure no orphaned DB record remains.",
    status_code=201,
)
async def upload_resource_metadata(
    request: Request,
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    project_id: Annotated[int, Form()],
    file_name: Annotated[str, Form()],
    file_label: Annotated[str | None, Form()] = None,
) -> ResourceUploadResponse:
    # Enforce upload size limit
    validate_upload_size(request)
    # Check project existence
    project = (
        await db.execute(select(Project).where(Project.id == project_id))
    ).scalar_one_or_none()
    if not project:
        logger.warning(f"Project {project_id} not found.")
        raise HTTPException(status_code=404, detail="Project not found.")
    # Check user membership
    assoc = (
        await db.execute(
            select(ProjectUserAssociation).where(
                ProjectUserAssociation.project_id == project_id,
                ProjectUserAssociation.user_id == current_user.id,
            )
        )
    ).scalar_one_or_none()
    if not assoc:
        logger.warning(
            f"User {current_user.id} is not authorized for project {project_id}.",
        )
        raise HTTPException(status_code=403, detail="Not authorized for this project.")
    # Now validate filename
    validate_upload_filename(file_name)
    resource, presigned_url, task = await create_upload_resource_and_task_service(
        db=db,
        file_name=file_name,
        project_id=project_id,
        file_label=file_label,
        user=current_user,
    )
    logger.info(
        f"Created upload resource and task for {file_name} in project {project_id} for user {current_user.email}.",
    )
    return ResourceUploadResponse(
        resource_id=resource.id,
        presigned_url=presigned_url,
        resource=ResourceUploadMeta(
            file_name=resource.file_name,
        ),
    )


@router.get(
    "/{upload_id}/status",
    summary="Get status of a hash upload task",
    description="Return the status and metadata for a hash upload task, including hash type, preview, and validation state.",
)
async def get_upload_status(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    upload_id: Annotated[int, Path(description="Upload task ID")],
) -> UploadStatusOut:
    return await get_upload_status_service(db, current_user, upload_id)


@router.get(
    "/{upload_id}/errors",
    summary="Get paginated list of failed lines for an upload task",
    description="Return paginated UploadErrorEntry objects for a given upload task.",
)
async def get_upload_errors(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    upload_id: Annotated[int, Path(description="Upload task ID")],
    page: Annotated[int, Query(ge=1, le=100)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 20,
) -> UploadErrorEntryListResponse:
    return await get_upload_errors_service(db, current_user, upload_id, page, page_size)
