from typing import Any

from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.hash_list import HashList


class HashListFactory(SQLAlchemyFactory[HashList]):
    __model__ = HashList
    __set_relationships__ = False  # Don't auto-create hash items
    __async_session__ = None
    name = Use(lambda: "hashlist-factory")
    description = Use(lambda: "Test hash list")
    # These must be set explicitly in tests - no defaults for required foreign keys
    project_id = None  # Must be set explicitly in tests
    hash_type_id = 0  # MD5 - always exists in pre-seeded data
    is_unavailable = False

    @classmethod
    async def create_async_with_hash_type(
        cls,
        hash_type_id: int = 0,
        **kwargs: Any,
    ) -> HashList:
        """Create a hash list ensuring the hash type exists.

        This method should be used instead of create_async to ensure
        the hash type is properly created or retrieved.
        """
        from sqlalchemy.ext.asyncio import AsyncSession

        from tests.utils.hash_type_utils import get_or_create_hash_type

        if cls.__async_session__ is None:
            raise ValueError("__async_session__ must be set before using this factory")

        # Get the actual session instance
        session = cls.__async_session__
        if not isinstance(session, AsyncSession):
            raise ValueError("__async_session__ must be an AsyncSession instance")  # noqa: TRY004

        # Ensure the hash type exists
        await get_or_create_hash_type(session, hash_type_id)

        # Create the hash list with the hash_type_id
        kwargs["hash_type_id"] = hash_type_id
        return await cls.create_async(**kwargs)


# Don't try to override build or create_async methods
