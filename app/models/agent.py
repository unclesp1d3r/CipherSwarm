"""Agent model for CipherSwarm distributed cracking agents."""

import enum
from datetime import datetime
from typing import TYPE_CHECKING, Any
from uuid import UUID, uuid4

from sqlalchemy import JSON, Boolean, DateTime, Enum, ForeignKey, Index, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.association_tables import project_agents
from app.models.base import Base
from app.models.operating_system import OperatingSystem
from app.models.user import User

if TYPE_CHECKING:
    from app.models.project import Project


class AgentState(enum.Enum):
    """Enum for agent states."""

    pending = "pending"
    active = "active"
    error = "error"
    offline = "offline"
    disabled = "disabled"


class AgentType(enum.Enum):
    """Enum for agent types."""

    physical = "physical"
    virtual = "virtual"
    container = "container"


class Agent(Base):
    """Represents a distributed cracking agent in CipherSwarm."""

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    client_signature: Mapped[str] = mapped_column(String(length=128), nullable=False)
    host_name: Mapped[str] = mapped_column(String(length=128), nullable=False)
    custom_label: Mapped[str | None] = mapped_column(
        String(length=128), unique=True, nullable=True, index=True
    )
    token: Mapped[str] = mapped_column(
        String(length=128), unique=True, nullable=False, index=True
    )
    last_seen_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    last_ipaddress: Mapped[str | None] = mapped_column(String(length=45), nullable=True)
    state: Mapped[AgentState] = mapped_column(
        Enum(AgentState), nullable=False, index=True
    )
    enabled: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    advanced_configuration: Mapped[dict[str, Any] | None] = mapped_column(
        JSON, nullable=True
    )
    devices: Mapped[list[str] | None] = mapped_column(JSON, nullable=True)
    agent_type: Mapped[AgentType | None] = mapped_column(Enum(AgentType), nullable=True)
    operating_system_id: Mapped[UUID] = mapped_column(
        ForeignKey("operatingsystems.id"), nullable=False
    )
    operating_system: Mapped[OperatingSystem] = relationship("OperatingSystem")
    user_id: Mapped[UUID | None] = mapped_column(ForeignKey("user.id"), nullable=True)
    user: Mapped[User | None] = relationship("User")
    projects: Mapped[list["Project"]] = relationship(
        "Project", secondary=project_agents, back_populates="agents", lazy="selectin"
    )
    __table_args__ = (
        Index("ix_agent_token", "token", unique=True),
        Index("ix_agent_state", "state"),
        Index("ix_agent_custom_label", "custom_label", unique=True),
    )

    # Relationships
    tasks = relationship("Task", back_populates="agent")
    benchmarks = relationship(
        "HashcatBenchmark", back_populates="agent", cascade="all, delete-orphan"
    )
    # benchmarks = relationship("HashcatBenchmark", back_populates="agent")  # TODO: Phase 4 - implement when benchmark ingestion is built
