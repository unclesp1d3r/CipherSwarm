from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Header, HTTPException, status

from app.core.exceptions import ResourceNotFoundError
from app.core.services.resource_service import (
    InvalidAgentTokenError,
    get_resource_download_url_service,
)

router = APIRouter(prefix="/resources", tags=["Resources"])


class ResourceDownloadResponseStub:
    url: str


# This is a garbage endpoint only used for testing purposes until the API is implemented.
# DO NOT USE THIS ENDPOINT IN PRODUCTION.
# The proper endpoint will be /api/v1/resources/{resource_id}/download
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
