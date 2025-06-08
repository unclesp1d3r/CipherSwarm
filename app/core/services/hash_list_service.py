from typing import Annotated

from loguru import logger
from pydantic import BaseModel, Field
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.hash_list import HashList
from app.models.user import User
from app.schemas.hash_list import HashListCreate, HashListOut


class HashListUpdateData(BaseModel):
    """Schema for updating a hash list."""

    name: Annotated[
        str | None,
        Field(description="Name of the hash list", min_length=1, max_length=128),
    ] = None
    description: Annotated[
        str | None, Field(description="Description of the hash list", max_length=512)
    ] = None
    is_unavailable: Annotated[
        bool | None, Field(description="True if the hash list is not yet ready for use")
    ] = None


class HashListNotFoundError(Exception):
    """Raised when a hash list is not found."""


async def create_hash_list_service(
    data: HashListCreate,
    db: AsyncSession,
    current_user: User,  # noqa: ARG001
) -> HashListOut:
    """
    Create a new hash list.

    Args:
        data: The hash list creation data
        db: Database session
        current_user: The current user (for audit/logging)

    Returns:
        HashListOut: The created hash list
    """
    logger.debug(f"Creating hash list with data: {data}")

    hash_list = HashList(
        name=data.name,
        description=data.description,
        project_id=data.project_id,
        hash_type_id=data.hash_type_id,
        is_unavailable=data.is_unavailable,
    )

    db.add(hash_list)
    await db.commit()
    await db.refresh(hash_list)

    logger.info(f"Hash list created: {data.name} (ID: {hash_list.id})")

    # Load with items relationship to match schema expectations
    result = await db.execute(
        select(HashList)
        .options(selectinload(HashList.items))
        .where(HashList.id == hash_list.id)
    )
    hash_list_with_items = result.scalar_one()

    return HashListOut.model_validate(hash_list_with_items, from_attributes=True)


async def list_hash_lists_service(
    db: AsyncSession,
    skip: int = 0,
    limit: int = 20,
    name_filter: str | None = None,
    project_id: int | None = None,
) -> tuple[list[HashListOut], int]:
    """
    List hash lists with pagination and filtering.

    Args:
        db: Database session
        skip: Number of records to skip
        limit: Maximum number of records to return
        name_filter: Optional name filter
        project_id: Optional project ID filter

    Returns:
        tuple[list[HashListOut], int]: List of hash lists and total count
    """
    stmt = HashList.available_query(project_id)

    if name_filter:
        stmt = stmt.where(HashList.name.ilike(f"%{name_filter}%"))

    # Get total count
    total_stmt = select(func.count()).select_from(stmt.subquery())
    total_result = await db.execute(total_stmt)
    total_count = total_result.scalar_one()

    # Get paginated results with items loaded
    stmt = (
        stmt.options(selectinload(HashList.items))
        .order_by(HashList.created_at.desc())
        .offset(skip)
        .limit(limit)
    )

    result = await db.execute(stmt)
    hash_lists = result.scalars().all()

    return [
        HashListOut.model_validate(hl, from_attributes=True) for hl in hash_lists
    ], total_count


async def get_hash_list_service(hash_list_id: int, db: AsyncSession) -> HashListOut:
    """
    Get a hash list by ID.

    Args:
        hash_list_id: The hash list ID
        db: Database session

    Returns:
        HashListOut: The hash list

    Raises:
        HashListNotFoundError: If hash list is not found
    """
    result = await db.execute(
        select(HashList)
        .options(selectinload(HashList.items))
        .where(HashList.id == hash_list_id)
    )
    hash_list = result.scalar_one_or_none()

    if not hash_list:
        raise HashListNotFoundError(f"Hash list {hash_list_id} not found")

    return HashListOut.model_validate(hash_list, from_attributes=True)


async def update_hash_list_service(
    hash_list_id: int, data: HashListUpdateData, db: AsyncSession
) -> HashListOut:
    """
    Update a hash list.

    Args:
        hash_list_id: The hash list ID
        data: The update data
        db: Database session

    Returns:
        HashListOut: The updated hash list

    Raises:
        HashListNotFoundError: If hash list is not found
    """
    result = await db.execute(select(HashList).where(HashList.id == hash_list_id))
    hash_list = result.scalar_one_or_none()

    if not hash_list:
        raise HashListNotFoundError(f"Hash list {hash_list_id} not found")

    # Update only provided fields
    update_data = data.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(hash_list, field, value)

    await db.commit()
    await db.refresh(hash_list)

    # Load with items relationship to match schema expectations
    result = await db.execute(
        select(HashList)
        .options(selectinload(HashList.items))
        .where(HashList.id == hash_list.id)
    )
    hash_list_with_items = result.scalar_one()

    logger.info(f"Hash list updated: {hash_list.name} (ID: {hash_list.id})")

    return HashListOut.model_validate(hash_list_with_items, from_attributes=True)


async def delete_hash_list_service(hash_list_id: int, db: AsyncSession) -> None:
    """
    Delete a hash list.

    Args:
        hash_list_id: The hash list ID
        db: Database session

    Raises:
        HashListNotFoundError: If hash list is not found
    """
    result = await db.execute(select(HashList).where(HashList.id == hash_list_id))
    hash_list = result.scalar_one_or_none()

    if not hash_list:
        raise HashListNotFoundError(f"Hash list {hash_list_id} not found")

    await db.delete(hash_list)
    await db.commit()

    logger.info(f"Hash list deleted: {hash_list.name} (ID: {hash_list.id})")
