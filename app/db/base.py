"""Base model module with common fields for all database models."""

from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import DateTime, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """Base class for all database models.

    This class provides common fields and functionality that all database models
    should inherit. It includes:
    - UUID primary key
    - Created at timestamp
    - Updated at timestamp with automatic updates
    """

    id: Mapped[UUID] = mapped_column(
        primary_key=True, default=uuid4, doc="Primary key UUID"
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
        doc="Record creation timestamp",
    )

    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
        doc="Record last update timestamp",
    )

    def __repr__(self) -> str:
        """Return string representation of the model.

        Returns:
            str: String representation including model name and ID
        """
        return f"<{self.__class__.__name__}(id={self.id})>"
