"""AgentError model for tracking errors reported by CipherSwarm agents."""

import enum
from uuid import UUID, uuid4

from sqlalchemy import JSON, Enum, ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.agent import Agent
from app.models.base import Base
from app.models.task import Task


class Severity(enum.Enum):
    info = "info"
    warning = "warning"
    minor = "minor"
    major = "major"
    critical = "critical"
    fatal = "fatal"


class AgentError(Base):
    """Represents an error reported by a CipherSwarm agent.

    Attributes:
        id: Unique identifier for the error event.
        message: Human-readable error message.
        severity: Severity level of the error.
        error_code: Optional error code for programmatic handling.
        details: Optional structured data with additional error context.
        agent_id: Foreign key to the reporting agent.
        agent: Relationship to the Agent model.
        task_id: Optional foreign key to the related task.
        task: Relationship to the Task model.
    """

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    message: Mapped[str] = mapped_column(String(length=512), nullable=False)
    severity: Mapped[Severity] = mapped_column(Enum(Severity), nullable=False)
    error_code: Mapped[str | None] = mapped_column(String(length=64), nullable=True)
    details: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    agent_id: Mapped[UUID] = mapped_column(
        ForeignKey("agents.id"), nullable=False, index=True
    )
    agent: Mapped[Agent] = relationship("Agent")
    task_id: Mapped[UUID | None] = mapped_column(
        ForeignKey("tasks.id"), nullable=True, index=True
    )
    task: Mapped[Task | None] = relationship("Task")
    __table_args__ = (
        Index("ix_agent_error_agent_id", "agent_id"),
        Index("ix_agent_error_task_id", "task_id"),
    )
