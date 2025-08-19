from datetime import datetime

from sqlalchemy import DateTime, Integer, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Resource(Base):
    """Resource model for storing attack resources like wordlists, rules, etc."""

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    resource_type: Mapped[str] = mapped_column(
        String(50), nullable=False, index=True
    )  # wordlist, rules, masks, etc.
    file_path: Mapped[str] = mapped_column(
        String(500), nullable=False
    )  # Path in MinIO/S3
    file_hash: Mapped[str | None] = mapped_column(
        String(128), nullable=True
    )  # SHA256 hash for verification
    file_size: Mapped[int | None] = mapped_column(
        Integer, nullable=True
    )  # File size in bytes
    content_type: Mapped[str] = mapped_column(
        String(100), nullable=False, default="application/octet-stream"
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
