from typing import ClassVar
from uuid import uuid4

from polyfactory import Use
from polyfactory.factories.sqlalchemy_factory import SQLAlchemyFactory

from app.models.attack_resource_file import AttackResourceFile, AttackResourceType


class AttackResourceFileFactory(SQLAlchemyFactory[AttackResourceFile]):
    __model__ = AttackResourceFile
    __async_session__ = None
    file_name = "test_resource.txt"
    download_url = "https://example.com/resource.txt"
    checksum = "deadbeef" * 8  # 64 chars
    guid = Use(lambda: uuid4())
    resource_type = AttackResourceType.WORD_LIST
    line_format = "freeform"
    line_encoding = "utf-8"
    used_for_modes: ClassVar[list[str]] = ["dictionary"]
    source = "upload"
