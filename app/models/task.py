from datetime import datetime
from enum import Enum
from typing import Optional

from sqlalchemy import Integer, String, ForeignKey, Enum as SQLAEnum
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

    attack_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("attacks.id"), nullable=False
    )
    agent_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("agents.id"), nullable=True
    )
    start_date: Mapped[datetime] = mapped_column(nullable=False)
    status: Mapped[TaskStatus] = mapped_column(
        SQLAEnum(TaskStatus), default=TaskStatus.PENDING, nullable=False
    )
    skip: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    limit: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)

    # Error handling
    error_message: Mapped[Optional[str]] = mapped_column(String(1024), nullable=True)
    error_details: Mapped[Optional[dict]] = mapped_column(JSON, nullable=True)

    # Progress tracking
    progress: Mapped[Optional[float]] = mapped_column(Float, default=0.0, nullable=True)
    estimated_completion: Mapped[Optional[datetime]] = mapped_column(nullable=True)

    # Relationships
    attack = relationship("Attack", back_populates="tasks")
    agent = relationship("Agent", back_populates="tasks")
    results = relationship("HashcatResult", back_populates="task")
    status_updates = relationship("TaskStatus", back_populates="task")
