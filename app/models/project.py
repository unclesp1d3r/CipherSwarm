"""Project model and association table for CipherSwarm workspaces/campaigns."""

from datetime import datetime
from typing import TYPE_CHECKING
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.association_tables import project_agents, project_users
from app.models.base import Base

if TYPE_CHECKING:
    from app.models.agent import Agent
    from app.models.user import User


class Project(Base):
    """Project model representing a workspace or campaign grouping.

    Supports many-to-many relationship with users and agents.
    """

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    name: Mapped[str] = mapped_column(
        String(length=128), unique=True, nullable=False, index=True
    )
    description: Mapped[str | None] = mapped_column(String(length=512), nullable=True)
    private: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    archived_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    notes: Mapped[str | None] = mapped_column(String(length=1024), nullable=True)
    users: Mapped[list["User"]] = relationship(
        "User", secondary=project_users, back_populates="projects", lazy="selectin"
    )
    agents: Mapped[list["Agent"]] = relationship(
        "Agent", secondary=project_agents, back_populates="projects", lazy="selectin"
    )
    attacks = relationship("Attack", back_populates="campaign", lazy="selectin")
