import os
from uuid import UUID

from sqlalchemy import desc, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import InvalidAgentTokenError
from app.models.attack_resource_file import AttackResourceFile, AttackResourceType


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


async def get_resource_content_service(
    resource_id: UUID, db: AsyncSession
) -> tuple[AttackResourceFile | None, str | None, str | None, int]:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        return None, None, "Resource not found", 404
    max_lines = int(os.getenv("RESOURCE_EDIT_MAX_LINES", "5000"))
    max_bytes = int(os.getenv("RESOURCE_EDIT_MAX_SIZE_MB", "1")) * 1024 * 1024
    if resource.resource_type == AttackResourceType.DYNAMIC_WORD_LIST:
        return (
            resource,
            None,
            "This resource is read-only and cannot be edited inline.",
            403,
        )
    if resource.line_count > max_lines or resource.byte_size > max_bytes:
        return (
            resource,
            None,
            f"This resource is too large to edit inline (max {max_lines} lines, {max_bytes // 1024 // 1024}MB). Download and edit offline.",
            403,
        )
    if resource.resource_type not in {
        AttackResourceType.MASK_LIST,
        AttackResourceType.RULE_LIST,
        AttackResourceType.WORD_LIST,
        AttackResourceType.CHARSET,
    }:
        return resource, None, "This resource type cannot be edited inline.", 403
    # Load content from storage (stub: replace with actual S3 or file backend)
    # For now, just return a placeholder or fake content
    # TODO: Integrate with MinIO or file backend to fetch actual content
    fake_content = (
        f"# Resource: {resource.file_name}\n# (Replace with actual file content)\n"
    )
    return resource, fake_content, None, 200


async def list_wordlists_service(
    db: AsyncSession, q: str = ""
) -> list[AttackResourceFile]:
    stmt = select(AttackResourceFile).where(
        AttackResourceFile.resource_type == AttackResourceType.WORD_LIST
    )
    if q:
        stmt = stmt.where(AttackResourceFile.file_name.ilike(f"%{q}%"))
    stmt = stmt.order_by(desc(AttackResourceFile.updated_at))
    result = await db.execute(stmt)
    return list(result.scalars().all())


__all__ = [
    "InvalidAgentTokenError",
    "ResourceNotFoundError",
    "get_resource_content_service",
    "get_resource_download_url_service",
    "list_wordlists_service",
]
