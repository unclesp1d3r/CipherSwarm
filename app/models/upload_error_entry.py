from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class UploadErrorEntry(Base):
    """Model for a failed line or error during hash upload processing."""

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    upload_id: Mapped[int] = mapped_column(
        ForeignKey("hash_upload_tasks.id"), nullable=False, index=True
    )
    line_number: Mapped[int | None] = mapped_column(Integer, nullable=True)
    raw_line: Mapped[str] = mapped_column(String(1024), nullable=False)
    error_message: Mapped[str] = mapped_column(String(512), nullable=False)

    upload_task = relationship("HashUploadTask", back_populates="errors")
    raw_hash = relationship(
        "RawHash", back_populates="upload_error_entry", uselist=False
    )
