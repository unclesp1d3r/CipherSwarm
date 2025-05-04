from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.deps import get_db
from app.core.services.resource_service import (
    InvalidAgentTokenError,
    InvalidUserAgentError,
    ResourceNotFoundError,
    get_resource_download_url_service,
)

# from app.models.resource import Resource  # TODO: Implement actual model
# from app.schemas.resource import ResourceDownloadResponse  # TODO: Implement actual schema

router = APIRouter()


class ResourceDownloadResponseStub:
    url: str


@router.get(
    "/{resource_id}/download",
    status_code=status.HTTP_200_OK,
    summary="Get resource download URL",
    description="Generate a presigned URL for the given resource. Requires valid Authorization and User-Agent headers.",
)
async def get_resource_download_url(
    resource_id: UUID,
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str, Header(alias="Authorization")],
    user_agent: Annotated[str, Header(..., alias="User-Agent")],
) -> dict[str, str]:
    try:
        url = await get_resource_download_url_service(
            resource_id, db, authorization, user_agent
        )
        return {"url": url}
    except InvalidUserAgentError as e:
        raise HTTPException(status_code=400, detail=str(e)) from e
    except InvalidAgentTokenError as e:
        raise HTTPException(status_code=401, detail=str(e)) from e
    except ResourceNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e)) from e
