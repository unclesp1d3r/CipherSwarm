from typing import Annotated

from fastapi import APIRouter, Depends, Form, Path
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.services.resource_service import (
    create_upload_resource_and_task_service,
    get_upload_status_service,
)
from app.db.session import get_db
from app.models.user import User
from app.schemas.resource import (
    ResourceUploadMeta,
    ResourceUploadResponse,
    UploadStatusOut,
)

router = APIRouter(prefix="/uploads", tags=["Uploads"])


@router.post(
    "/",
    summary="Upload metadata, request presigned upload URL for UploadResourceFile",
    description="Create an UploadResourceFile DB record, a HashUploadTask, and return a presigned S3 upload URL. If upload fails, ensure no orphaned DB record remains.",
    status_code=201,
)
async def upload_resource_metadata(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    project_id: Annotated[int, Form()],
    file_name: Annotated[str, Form()],
    file_label: Annotated[str | None, Form()] = None,
) -> ResourceUploadResponse:
    resource, presigned_url, task = await create_upload_resource_and_task_service(
        db=db,
        file_name=file_name,
        project_id=project_id,
        file_label=file_label,
        user=current_user,
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
