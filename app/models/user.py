import enum
from datetime import UTC, datetime
from typing import TYPE_CHECKING

from fastapi_users_db_sqlalchemy import SQLAlchemyBaseUserTableUUID
from sqlalchemy import DateTime, Enum, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.association_tables import project_users
from app.models.base import UnifiedBase

if TYPE_CHECKING:
    from app.models.project import Project


class UserRole(enum.Enum):
    admin = "admin"
    analyst = "analyst"
    operator = "operator"


class User(SQLAlchemyBaseUserTableUUID, UnifiedBase):
    """User model for authentication and access control, compatible with fastapi-users.
    Extends SQLAlchemyBaseUserTableUUID for UUID primary key and required fields.
    """

    # Do NOT inherit from Base. This avoids __tablename__ conflicts with SQLAlchemyBaseUserTableUUID.

    name: Mapped[str] = mapped_column(
        String(length=128), unique=True, nullable=False, index=True
    )
    role: Mapped[UserRole] = mapped_column(
        Enum(UserRole), nullable=False, default=UserRole.analyst
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
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(UTC), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
        nullable=False,
    )
    projects: Mapped[list["Project"]] = relationship(
        "Project", secondary=project_users, back_populates="users", lazy="selectin"
    )
    # Additional custom fields can be added here
