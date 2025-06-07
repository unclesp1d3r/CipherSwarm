import random

from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.hash_type import HashType


class HashTypeFactory(SQLAlchemyFactory[HashType]):
    __model__ = HashType
    __async_session__ = None  # Will be set in tests before use
    id = Use(
        lambda: random.randint(1000, 99999)
    )  # Generate random ID to avoid conflicts
    name = "sha512crypt"
    description = "SHA512 crypt (Unix shadow)"
    john_mode = None
