from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, status

from app.core.services.resource_service import (
    InvalidAgentTokenError,
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
    description="Generate a presigned URL for the given resource. Requires valid Authorization.",
)
async def get_resource_download_url(
    resource_id: UUID,  # This must be a UUID, not an int, unlike nearly all other IDs (except for user IDs)
    authorization: Annotated[str, Header(alias="Authorization")],
) -> dict[str, str]:
    try:
        url = await get_resource_download_url_service(resource_id, authorization)

    except InvalidAgentTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e)
        ) from e
    except ResourceNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e)) from e
    else:
        return {"url": url}
