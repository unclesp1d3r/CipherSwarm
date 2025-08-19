import logging

from fastapi import APIRouter, Depends, HTTPException, Path, status
from sqlalchemy.orm import Session

from app.core.deps import get_current_agent_v2, get_db
from app.core.services.agent_v2_service import agent_v2_service
from app.models.agent import Agent
from app.schemas.agent_v2 import ResourceUrlRequestV2, ResourceUrlResponseV2

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/client/agents/resources",
    tags=["Resource Access"],
    responses={
        401: {"description": "Invalid or missing agent token"},
        403: {"description": "Agent not authorized for this resource"},
        404: {"description": "Resource not found"},
    },
)


@router.get(
    "/{resource_id}/url",
    response_model=ResourceUrlResponseV2,
    status_code=status.HTTP_200_OK,
    summary="Get presigned resource URL",
    description="""
    Generate time-limited presigned URL for downloading attack resources.
    
    This endpoint allows agents to access presigned URLs for downloading attack
    resources such as wordlists, rules, masks, and other files needed for cracking
    operations. The server validates agent authorization and generates time-limited
    URLs with hash verification requirements.
    
    **Authentication**: Required - Bearer token (`csa_<agent_id>_<token>`)
    
    **Authorization**: Agent must be authorized to access the specific resource
    
    **Requirements**:
    - Valid agent token in Authorization header
    - Resource must exist and be accessible
    - Agent must have permission to access the resource
    
    **URL Expiration**: Default 1 hour (configurable)
    """,
    responses={
        200: {
            "description": "Presigned URL generated successfully",
            "content": {
                "application/json": {
                    "example": {
                        "resource_id": 123,
                        "download_url": "https://storage.example.com/bucket/resource?signature=...",
                        "expires_at": "2024-01-01T01:00:00Z",
                        "expected_hash": "sha256:abc123def456...",
                        "file_size": 1048576,
                        "content_type": "text/plain",
                    }
                }
            },
        }
    },
)
async def get_resource_url(
    resource_id: int = Path(
        ..., description="The ID of the resource to get download URL for", ge=1
    ),
    request_data: ResourceUrlRequestV2 | None = None,
    current_agent: Agent = Depends(get_current_agent_v2),
    db: Session = Depends(get_db),
) -> ResourceUrlResponseV2:
    """Get presigned URL for downloading a resource.

    This endpoint allows agents to access presigned URLs for downloading
    attack resources such as wordlists, rules, and other files needed
    for cracking operations.
    """
    try:
        return agent_v2_service.generate_resource_url_v2_service(
            db, current_agent, resource_id, request_data
        )
    except ValueError as e:
        if "not found" in str(e).lower():
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
        if "not authorized" in str(e).lower():
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception as e:
        logger.error(f"Unexpected error generating resource URL: {e!s}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate resource URL",
        )
