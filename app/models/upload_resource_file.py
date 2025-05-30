from uuid import UUID, uuid4

from sqlalchemy import JSON, String
from sqlalchemy.ext.mutable import MutableDict
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class UploadResourceFile(Base):
    """Model for uploaded resource files used in the crackable upload pipeline only."""

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    project_id: Mapped[int | None] = mapped_column(nullable=True)
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    download_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    checksum: Mapped[str] = mapped_column(String(64), nullable=False)
    guid: Mapped[UUID] = mapped_column(default=uuid4, unique=True, nullable=False)
    line_format: Mapped[str] = mapped_column(
        String(32), nullable=False, default="freeform"
    )
    line_encoding: Mapped[str] = mapped_column(
        String(16), nullable=False, default="utf-8"
    )
    source: Mapped[str] = mapped_column(String(32), nullable=False, default="upload")
    line_count: Mapped[int] = mapped_column(nullable=False, default=0)
    byte_size: Mapped[int] = mapped_column(nullable=False, default=0)
    content: Mapped[dict[str, object] | None] = mapped_column(
        MutableDict.as_mutable(JSON), nullable=True, default=None
    )
    is_uploaded: Mapped[bool] = mapped_column(nullable=False, default=False)
    file_label: Mapped[str | None] = mapped_column(
        String(50), nullable=True, default=None
    )
    tags: Mapped[list[str] | None] = mapped_column(JSON, nullable=True, default=None)

    def __repr__(self) -> str:
        return (
            f"<UploadResourceFile(id={self.id}, file_name={self.file_name}, "
            f"line_format={self.line_format}, line_encoding={self.line_encoding}, source={self.source}, "
            f"line_count={self.line_count}, byte_size={self.byte_size}, is_uploaded={self.is_uploaded})>"
        )
