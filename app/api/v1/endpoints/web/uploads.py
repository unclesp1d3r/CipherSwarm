from typing import Annotated

from fastapi import APIRouter, Depends, Form
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_current_user
from app.core.services.resource_service import (
    create_upload_resource_and_presign_service,
)
from app.db.session import get_db
from app.models.user import User
from app.schemas.resource import ResourceUploadMeta, ResourceUploadResponse

router = APIRouter(prefix="/uploads", tags=["Uploads"])


@router.post(
    "/",
    summary="Upload metadata, request presigned upload URL for UploadResourceFile",
    description="Create an UploadResourceFile DB record and return a presigned S3 upload URL. If upload fails, ensure no orphaned DB record remains.",
    status_code=201,
)
async def upload_resource_metadata(
    db: Annotated[AsyncSession, Depends(get_db)],
    current_user: Annotated[User, Depends(get_current_user)],
    project_id: Annotated[int, Form()],
    file_name: Annotated[str, Form()],
    file_label: Annotated[str | None, Form()] = None,
) -> ResourceUploadResponse:
    resource, presigned_url = await create_upload_resource_and_presign_service(
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
