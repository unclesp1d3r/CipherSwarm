from sqlalchemy import JSON, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class RawHash(Base):
    """Model for raw hashes extracted from uploaded files."""

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    hash: Mapped[str] = mapped_column(String(512), nullable=False)
    hash_type_id: Mapped[int] = mapped_column(
        ForeignKey("hash_types.id"), nullable=False
    )
    username: Mapped[str | None] = mapped_column(String(255), nullable=True)
    meta: Mapped[dict[str, str] | None] = mapped_column(JSON, nullable=True)
    line_number: Mapped[int] = mapped_column(Integer, nullable=False)
    upload_error_entry_id: Mapped[int | None] = mapped_column(
        ForeignKey("upload_error_entrys.id"),
        nullable=True,
    )  # The table name generator isn't smart enough to handle plural entries vs entrys
    upload_task_id: Mapped[int] = mapped_column(
        ForeignKey("hash_upload_tasks.id"), nullable=False
    )

    hash_type = relationship("HashType")
    upload_task = relationship("HashUploadTask", back_populates="raw_hashes")
    upload_error_entry = relationship("UploadErrorEntry", back_populates="raw_hash")
