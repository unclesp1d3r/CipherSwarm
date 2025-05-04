from datetime import datetime
from enum import Enum
from typing import Any
from uuid import UUID

from sqlalchemy import JSON, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy import Enum as SQLAEnum
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class TaskStatus(str, Enum):
    """Enum for task statuses."""

    PENDING = "pending"
    RUNNING = "running"
    PAUSED = "paused"
    COMPLETED = "completed"
    FAILED = "failed"
    ABANDONED = "abandoned"


class Task(Base):
    """Model for cracking tasks."""

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    attack_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("attacks.id"), nullable=False
    )
    agent_id: Mapped[UUID | None] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("agents.id"), nullable=True
    )
    start_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    status: Mapped[TaskStatus] = mapped_column(
        SQLAEnum(TaskStatus), default=TaskStatus.PENDING, nullable=False
    )
    skip: Mapped[int | None] = mapped_column(Integer, nullable=True)
    limit: Mapped[int | None] = mapped_column(Integer, nullable=True)

    # Error handling
    error_message: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    error_details: Mapped[dict[str, Any] | None] = mapped_column(JSON, nullable=True)

    # Progress tracking
    progress: Mapped[float | None] = mapped_column(Float, default=0.0, nullable=True)
    estimated_completion: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )

    # Relationships
    attack = relationship("Attack", back_populates="tasks")
    agent = relationship("Agent", back_populates="tasks")
    # results = relationship("HashcatResult", back_populates="task")  # TODO: Phase 4 - implement when result ingestion is built
    # status_updates = relationship("TaskStatus", back_populates="task")  # TODO: Only add if TaskStatus becomes a model
