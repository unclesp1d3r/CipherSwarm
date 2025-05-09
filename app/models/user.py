import uuid
from datetime import datetime
from enum import Enum as PyEnum

from sqlalchemy import Boolean, DateTime, Enum, Integer, String
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.associationproxy import association_proxy
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base
from app.models.project import ProjectUserAssociation


class UserRole(PyEnum):
    ADMIN = "admin"
    ANALYST = "analyst"
    OPERATOR = "operator"


class User(Base):
    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        primary_key=True,
        default=uuid.uuid4,
    )
    email: Mapped[str] = mapped_column(
        String(length=128), unique=True, nullable=False, index=True
    )
    hashed_password: Mapped[str] = mapped_column(String(length=128), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_superuser: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    project_associations = relationship(
        "ProjectUserAssociation", back_populates="user", cascade="all, delete-orphan"
    )
    projects = association_proxy(
        "project_associations",
        "project",
        creator=lambda project: ProjectUserAssociation(project=project),
    )
    name: Mapped[str] = mapped_column(
        String(length=128), unique=True, nullable=False, index=True
    )
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole), nullable=False, default=UserRole.ANALYST
    )
    sign_in_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    current_sign_in_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    last_sign_in_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )
    current_sign_in_ip: Mapped[str | None] = mapped_column(
        String(length=45), nullable=True
    )
    last_sign_in_ip: Mapped[str | None] = mapped_column(
        String(length=45), nullable=True
    )
    reset_password_token: Mapped[str | None] = mapped_column(
        String(length=128), unique=True, nullable=True, index=True
    )
    unlock_token: Mapped[str | None] = mapped_column(String(length=128), nullable=True)
    failed_attempts: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    totp_secret: Mapped[str | None] = mapped_column(String(length=64), nullable=True)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
