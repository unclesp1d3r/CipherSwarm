from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.upload_error_entry import UploadErrorEntry


class UploadErrorEntryFactory(SQLAlchemyFactory[UploadErrorEntry]):
    __model__ = UploadErrorEntry
    __async_session__ = None
    __check_model__ = False
    __set_relationships__ = False
    __set_association_proxy__ = False

    upload_id = None  # Must be set explicitly
    line_number = Use(lambda: 1)
    raw_line = Use(lambda: "invalid hash line")
    error_message = Use(lambda: "Invalid hash format")
