import random

from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.hash_type import HashType


class HashTypeFactory(SQLAlchemyFactory[HashType]):
    __model__ = HashType
    __async_session__ = None  # Will be set in tests before use
    __check_model__ = False
    __set_relationships__ = False
    __set_association_proxy__ = False
    id = Use(
        lambda: random.randint(100000, 999999)
    )  # Generate high random ID to avoid conflicts with seeded hash types
    name = Use(lambda: f"test-hash-type-{random.randint(1000, 9999)}")
    description = Use(lambda: f"Test hash type {random.randint(1000, 9999)}")
    john_mode = None

    @classmethod
    async def get_or_create_by_id(
        cls,
        hash_type_id: int,
        name: str | None = None,
        description: str | None = None,
    ) -> HashType:
        """Get or create a hash type by ID using the utility function."""
        from sqlalchemy.ext.asyncio import AsyncSession

        from tests.utils.hash_type_utils import get_or_create_hash_type

        if cls.__async_session__ is None:
            raise ValueError("__async_session__ must be set before using this factory")

        # Get the actual session instance
        session = cls.__async_session__
        if not isinstance(session, AsyncSession):
            raise ValueError("__async_session__ must be an AsyncSession instance")  # noqa: TRY004

        return await get_or_create_hash_type(session, hash_type_id, name, description)
