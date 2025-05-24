from typing import cast
from uuid import UUID, uuid4

from fastapi import HTTPException, status
from sqlalchemy import desc, func, select
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.authz import user_can_access_project_by_id
from app.core.config import settings
from app.core.exceptions import InvalidAgentTokenError
from app.models.attack_resource_file import AttackResourceFile, AttackResourceType
from app.models.user import User
from app.schemas.resource import ResourceLine, ResourceLineValidationError


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


def is_resource_editable(resource: AttackResourceFile) -> bool:
    max_lines = settings.RESOURCE_EDIT_MAX_LINES
    max_bytes = settings.RESOURCE_EDIT_MAX_SIZE_MB * 1024 * 1024
    if resource.resource_type == AttackResourceType.DYNAMIC_WORD_LIST:
        return False
    if resource.line_count > max_lines or resource.byte_size > max_bytes:
        return False
    return resource.resource_type in {
        AttackResourceType.MASK_LIST,
        AttackResourceType.RULE_LIST,
        AttackResourceType.WORD_LIST,
        AttackResourceType.CHARSET,
    }


async def get_resource_content_service(
    resource_id: UUID, db: AsyncSession
) -> tuple[AttackResourceFile | None, str | None, str | None, int, bool]:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        return None, None, "Resource not found", 404, False
    max_lines = settings.RESOURCE_EDIT_MAX_LINES
    max_bytes = settings.RESOURCE_EDIT_MAX_SIZE_MB * 1024 * 1024
    editable = is_resource_editable(resource)
    if resource.resource_type == AttackResourceType.DYNAMIC_WORD_LIST:
        return (
            resource,
            None,
            "This resource is read-only and cannot be edited inline.",
            403,
            editable,
        )
    if resource.line_count > max_lines or resource.byte_size > max_bytes:
        return (
            resource,
            None,
            f"This resource is too large to edit inline (max {max_lines} lines, {max_bytes // 1024 // 1024}MB). Download and edit offline.",
            403,
            editable,
        )
    if resource.resource_type not in {
        AttackResourceType.MASK_LIST,
        AttackResourceType.RULE_LIST,
        AttackResourceType.WORD_LIST,
        AttackResourceType.CHARSET,
    }:
        return (
            resource,
            None,
            "This resource type cannot be edited inline.",
            403,
            editable,
        )
    # Load content from storage (stub: replace with actual S3 or file backend)
    # For now, just return a placeholder or fake content
    # TODO: Integrate with MinIO or file backend to fetch actual content
    fake_content = (
        f"# Resource: {resource.file_name}\n# (Replace with actual file content)\n"
    )
    return resource, fake_content, None, 200, editable


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


async def list_rulelists_service(
    db: AsyncSession, q: str = ""
) -> list[AttackResourceFile]:
    stmt = select(AttackResourceFile).where(
        AttackResourceFile.resource_type == AttackResourceType.RULE_LIST
    )
    if q:
        stmt = stmt.where(AttackResourceFile.file_name.ilike(f"%{q}%"))
    stmt = stmt.order_by(desc(AttackResourceFile.updated_at))
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def get_resource_lines_service(
    resource_id: UUID,
    db: AsyncSession,
    page: int = 1,
    page_size: int = 100,
) -> list[ResourceLine]:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    if resource.resource_type not in {
        AttackResourceType.MASK_LIST,
        AttackResourceType.RULE_LIST,
        AttackResourceType.WORD_LIST,
        AttackResourceType.CHARSET,
    }:
        raise HTTPException(status_code=403, detail="Resource type not editable")
    if not resource.content or "lines" not in resource.content:
        raise HTTPException(status_code=400, detail="Resource has no editable lines")
    lines_raw = resource.content["lines"]
    if not isinstance(lines_raw, list):
        raise HTTPException(status_code=400, detail="Resource lines are not a list")
    lines: list[str] = cast("list[str]", lines_raw)
    start = (page - 1) * page_size
    end = start + page_size
    paged_lines = lines[start:end]
    result = []
    for idx, line in enumerate(paged_lines, start=start):
        valid, error = _validate_line(line, resource.resource_type)
        result.append(
            ResourceLine(
                id=idx,
                index=idx,
                content=line,
                valid=valid,
                error_message=error,
            )
        )
    return result


async def add_resource_line_service(
    resource_id: UUID, db: AsyncSession, line: str
) -> ResourceLine:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    if not resource.content or "lines" not in resource.content:
        raise HTTPException(status_code=400, detail="Resource has no editable lines")
    lines = resource.content["lines"]
    if not isinstance(lines, list):
        raise HTTPException(status_code=400, detail="Resource lines are not a list")
    valid, error = _validate_line(line, resource.resource_type)
    if not valid:
        raise HTTPException(
            status_code=422,
            detail=[
                ResourceLineValidationError(
                    line_index=len(lines),
                    content=line,
                    valid=False,
                    message=error or "",
                ).model_dump(mode="json")
            ],
        )
    lines.append(line)
    resource.content["lines"] = list(lines)
    resource.line_count = len(lines)
    resource.byte_size = sum(len(line_str) for line_str in lines)
    await db.commit()
    await db.refresh(resource)
    return ResourceLine(
        id=len(lines) - 1,
        index=len(lines) - 1,
        content=line,
        valid=True,
        error_message=None,
    )


async def update_resource_line_service(
    resource_id: UUID, line_id: int, db: AsyncSession, line: str
) -> ResourceLine:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    if not resource.content or "lines" not in resource.content:
        raise HTTPException(status_code=400, detail="Resource has no editable lines")
    lines = resource.content["lines"]
    if not isinstance(lines, list):
        raise HTTPException(status_code=400, detail="Resource lines are not a list")
    if not (0 <= line_id < len(lines)):
        raise HTTPException(status_code=404, detail="Line not found")
    valid, error = _validate_line(line, resource.resource_type)
    if not valid:
        raise HTTPException(
            status_code=422,
            detail=[
                ResourceLineValidationError(
                    line_index=line_id, content=line, valid=False, message=error or ""
                ).model_dump(mode="json")
            ],
        )
    lines[line_id] = line
    resource.content["lines"] = list(lines)
    resource.byte_size = sum(len(line_str) for line_str in lines)
    await db.commit()
    await db.refresh(resource)
    return ResourceLine(
        id=line_id, index=line_id, content=line, valid=True, error_message=None
    )


async def delete_resource_line_service(
    resource_id: UUID, line_id: int, db: AsyncSession
) -> None:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    if not resource.content or "lines" not in resource.content:
        raise HTTPException(status_code=400, detail="Resource has no editable lines")
    lines = resource.content["lines"]
    if not isinstance(lines, list):
        raise HTTPException(status_code=400, detail="Resource lines are not a list")
    if not (0 <= line_id < len(lines)):
        raise HTTPException(status_code=404, detail="Line not found")
    lines.pop(line_id)
    resource.content["lines"] = list(lines)
    resource.line_count = len(lines)
    resource.byte_size = sum(len(line_str) for line_str in lines)
    await db.commit()
    await db.refresh(resource)


async def validate_resource_lines_service(
    resource_id: UUID, db: AsyncSession
) -> list[ResourceLineValidationError]:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    if resource.resource_type not in {
        AttackResourceType.MASK_LIST,
        AttackResourceType.RULE_LIST,
        AttackResourceType.WORD_LIST,
        AttackResourceType.CHARSET,
    }:
        raise HTTPException(status_code=403, detail="Resource type not editable")
    if not resource.content or "lines" not in resource.content:
        raise HTTPException(status_code=400, detail="Resource has no editable lines")
    lines = resource.content["lines"]
    if not isinstance(lines, list):
        raise HTTPException(status_code=400, detail="Resource lines are not a list")
    errors: list[ResourceLineValidationError] = []
    for idx, line in enumerate(lines):
        valid, error = _validate_line(line, resource.resource_type)
        if not valid:
            errors.append(
                ResourceLineValidationError(
                    line_index=idx,
                    content=line,
                    valid=False,
                    message=error or "Invalid line",
                )
            )
    return errors


# Validation helpers


def _validate_line(
    line: str, resource_type: AttackResourceType
) -> tuple[bool, str | None]:
    # TODO: Implement real validation for mask/rule/charset
    if resource_type == AttackResourceType.MASK_LIST and (not line or " " in line):
        return False, "Invalid mask syntax"
    if resource_type == AttackResourceType.RULE_LIST and line and line.startswith("+"):
        return False, "Unknown rule operator"
    # Add more rules as needed
    return True, None


async def list_resources_service(
    db: AsyncSession,
    resource_type: AttackResourceType | None = None,
    q: str = "",
    page: int = 1,
    page_size: int = 25,
) -> tuple[list[AttackResourceFile], int]:
    stmt = select(AttackResourceFile)
    if resource_type:
        stmt = stmt.where(AttackResourceFile.resource_type == resource_type)
    if q:
        stmt = stmt.where(AttackResourceFile.file_name.ilike(f"%{q}%"))
    stmt = stmt.order_by(desc(AttackResourceFile.updated_at))
    total_count = await db.scalar(select(func.count()).select_from(stmt.subquery()))
    if total_count is None:
        total_count = 0
    stmt = stmt.offset((page - 1) * page_size).limit(page_size)
    result = await db.execute(stmt)
    return list(result.scalars().all()), total_count


async def create_resource_and_presign_service(
    db: AsyncSession,
    file_name: str,
    resource_type: AttackResourceType,
    project_id: int | None = None,
    description: str | None = None,
    tags: str | None = None,
    user_id: UUID | None = None,
) -> tuple[AttackResourceFile, str]:
    """
    Atomically create an AttackResourceFile DB record and generate a presigned S3 upload URL.
    If any error occurs, ensure no orphaned DB record remains.
    """
    resource = AttackResourceFile(
        file_name=file_name,
        resource_type=resource_type,
        project_id=project_id,
        description=description,
        tags=tags,
        guid=uuid4(),
        source="upload",
        created_by=user_id,
    )
    try:
        db.add(resource)
        await db.commit()
        await db.refresh(resource)
    except SQLAlchemyError as err:
        await db.rollback()
        raise RuntimeError(f"Failed to create resource DB record: {err}") from err
    else:
        # Generate presigned URL (stub for now)
        presigned_url = f"https://minio.local/resources/{resource.id}?presigned=stub"
        return resource, presigned_url


async def get_resource_or_404(
    resource_id: UUID, db: AsyncSession
) -> AttackResourceFile:
    resource = await db.get(AttackResourceFile, resource_id)
    if not resource:
        raise HTTPException(status_code=404, detail="Resource not found")
    return resource


async def check_resource_editable(resource: AttackResourceFile) -> None:
    max_lines = settings.RESOURCE_EDIT_MAX_LINES
    max_bytes = settings.RESOURCE_EDIT_MAX_SIZE_MB * 1024 * 1024
    if resource.resource_type == AttackResourceType.DYNAMIC_WORD_LIST:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Editing not allowed for dynamic word lists.",
        )
    if resource.line_count > max_lines or resource.byte_size > max_bytes:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Resource too large for in-browser editing.",
        )
    if resource.resource_type not in {
        AttackResourceType.MASK_LIST,
        AttackResourceType.RULE_LIST,
        AttackResourceType.WORD_LIST,
        AttackResourceType.CHARSET,
    }:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail="Resource type not editable."
        )


async def check_project_access(
    project_id: int,
    current_user: User,
    db: AsyncSession,
) -> None:
    if not user_can_access_project_by_id(
        current_user, project_id, action="update", db=db
    ):
        raise HTTPException(status_code=403, detail="Not authorized for this project.")


__all__ = [
    "InvalidAgentTokenError",
    "ResourceNotFoundError",
    "add_resource_line_service",
    "create_resource_and_presign_service",
    "delete_resource_line_service",
    "get_resource_content_service",
    "get_resource_download_url_service",
    "get_resource_lines_service",
    "list_resources_service",
    "list_rulelists_service",
    "list_wordlists_service",
    "update_resource_line_service",
    "validate_resource_lines_service",
]
