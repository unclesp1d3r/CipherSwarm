from datetime import datetime
from enum import Enum
from typing import Any

from sqlalchemy import DateTime, Float, ForeignKey, Integer, String
from sqlalchemy import Enum as SQLAEnum
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.ext.mutable import MutableDict
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

# Magic value for task completion percentage
TASK_COMPLETION_PERCENT: float = 100.0


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

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    attack_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("attacks.id"), nullable=False
    )
    agent_id: Mapped[int | None] = mapped_column(
        Integer, ForeignKey("agents.id"), nullable=True
    )
    start_date: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    status: Mapped[TaskStatus] = mapped_column(
        SQLAEnum(TaskStatus), default=TaskStatus.PENDING, nullable=False
    )
    skip: Mapped[int | None] = mapped_column(Integer, nullable=True)
    limit: Mapped[int | None] = mapped_column(Integer, nullable=True)

    retry_count: Mapped[int] = mapped_column(
        Integer, default=0, server_default="0", nullable=False
    )

    # Error handling
    error_message: Mapped[str | None] = mapped_column(String(1024), nullable=True)
    error_details: Mapped[dict[str, Any] | None] = mapped_column(
        MutableDict.as_mutable(JSONB), nullable=True
    )

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

    @property
    def keyspace_total(self) -> int:
        # Assume keyspace_total is stored in error_details or as a direct attribute in the future
        if self.error_details and "keyspace_total" in self.error_details:
            value = self.error_details["keyspace_total"]
            if isinstance(value, int):
                return value
            try:
                return int(value)
            except (ValueError, TypeError):
                return 0
        return 0

    @property
    def progress_percent(self) -> float:
        return self.progress if self.progress is not None else 0.0

    @property
    def is_complete(self) -> bool:
        result_submitted = False
        if self.error_details and "result_submitted" in self.error_details:
            result_submitted = bool(self.error_details["result_submitted"])
        return self.progress_percent >= TASK_COMPLETION_PERCENT or result_submitted
