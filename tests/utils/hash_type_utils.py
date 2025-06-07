from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.hash_type import HashType


async def get_or_create_hash_type(
    db_session: AsyncSession,
    hash_type_id: int,
    name: str | None = None,
    description: str | None = None,
) -> HashType:
    """Get an existing hash type or create it if it doesn't exist.

    This function should be used in tests instead of manually creating HashType records
    to avoid conflicts with the seeded hash types.

    Args:
        db_session: The database session
        hash_type_id: The hashcat mode ID
        name: Optional name (will use default if not provided)
        description: Optional description (will use default if not provided)

    Returns:
        The HashType instance
    """
    # First try to get the existing hash type
    result = await db_session.execute(
        select(HashType).where(HashType.id == hash_type_id)
    )
    hash_type = result.scalar_one_or_none()

    if hash_type:
        return hash_type

    # If it doesn't exist, create it with defaults
    if name is None:
        name = f"Test Hash Type {hash_type_id}"
    if description is None:
        description = f"Test description for mode {hash_type_id}"

    hash_type = HashType(
        id=hash_type_id,
        name=name,
        description=description,
    )
    db_session.add(hash_type)
    await db_session.commit()
    await db_session.refresh(hash_type)

    return hash_type
