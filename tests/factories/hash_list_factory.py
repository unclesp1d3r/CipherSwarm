from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.hash_list import HashList


class HashListFactory(SQLAlchemyFactory[HashList]):
    __model__ = HashList
    __set_relationships__ = True
    __async_session__ = None
    name = Use(lambda: "hashlist-factory")
    description = Use(lambda: "Test hash list")
    project_id = None  # Must be set explicitly in tests
    hash_type_id = 0


# Don't try to override build or create_async methods
