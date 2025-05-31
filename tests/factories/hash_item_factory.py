from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.hash_item import HashItem


class HashItemFactory(SQLAlchemyFactory[HashItem]):
    """Factory for creating HashItem objects.

    Fields:
        - hash (str): The hash value.
        - salt (str | None): The salt value, if present.
        - meta (dict[str, str] | None): Metadata for the hash item.
        - plain_text (str | None): The cracked plain text, if available.
    """

    __model__ = HashItem
    __async_session__ = None
    hash = Use(lambda: "deadbeef")
    salt = None
    meta = None
    plain_text = None


# Don't try to override build or create_async methods
