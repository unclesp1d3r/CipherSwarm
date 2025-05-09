from uuid import UUID

from app.core.exceptions import InvalidAgentTokenError


class ResourceNotFoundError(Exception):
    pass


async def get_resource_download_url_service(
    resource_id: UUID,  # This has to be a UUID, not an int
    authorization: str,
) -> str:
    if not authorization.startswith("Bearer csa_"):
        raise InvalidAgentTokenError("Invalid or missing agent token")
    # TODO: Validate agent token and fetch agent (stub for now)
    # TODO: Fetch resource by UUID (stub for now)
    # TODO: Generate presigned URL (stub for now)
    # TODO: Log download request (stub for now)
    return f"https://minio.local/resources/{resource_id}?presigned=stub"  # TODO: Move URL base to config


__all__ = [
    "InvalidAgentTokenError",
    "ResourceNotFoundError",
    "get_resource_download_url_service",
]
