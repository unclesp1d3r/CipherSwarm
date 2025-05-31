from typing import ClassVar

from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.raw_hash import RawHash


class RawHashFactory(SQLAlchemyFactory[RawHash]):
    __model__ = RawHash
    __async_session__ = None
    hash = "deadbeef"
    hash_type_id = 1  # Should be set explicitly in tests
    username = "alice"
    meta: ClassVar[dict[str, str]] = {"source": "test"}
    line_number = 1
    upload_error_entry_id = None
    upload_task_id = 1  # Should be set explicitly in tests
