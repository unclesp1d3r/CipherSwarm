from sqlalchemy import Column, DateTime, Integer, String, Text
from sqlalchemy.sql import func

from app.models.base import Base


class Resource(Base):
    """Resource model for storing attack resources like wordlists, rules, etc."""

    __tablename__ = "resources"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False, index=True)
    description = Column(Text, nullable=True)
    resource_type = Column(
        String(50), nullable=False, index=True
    )  # wordlist, rules, masks, etc.
    file_path = Column(String(500), nullable=False)  # Path in MinIO/S3
    file_hash = Column(String(128), nullable=True)  # SHA256 hash for verification
    file_size = Column(Integer, nullable=True)  # File size in bytes
    content_type = Column(
        String(100), nullable=False, default="application/octet-stream"
    )

    created_at = Column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at = Column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )
