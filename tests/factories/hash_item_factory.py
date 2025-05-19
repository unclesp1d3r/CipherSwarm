from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.hash_item import HashItem


class HashItemFactory(SQLAlchemyFactory[HashItem]):
    __model__ = HashItem
    __async_session__ = None
    hash = Use(lambda: "deadbeef")
    salt = None
    meta = None
    plain_text = None


# Don't try to override build or create_async methods
