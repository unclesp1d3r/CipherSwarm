from enum import Enum
from uuid import UUID, uuid4

from sqlalchemy import Enum as SQLAEnum
from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class AttackResourceType(str, Enum):
    MASK_LIST = "mask_list"
    RULE_LIST = "rule_list"
    WORD_LIST = "word_list"
    CHARSET = "charset"
    DYNAMIC_WORD_LIST = "dynamic_word_list"


class AttackResourceFile(Base):
    """Model for attack resource files (wordlists, rules, masks)."""

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    download_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    checksum: Mapped[str] = mapped_column(String(64), nullable=False)
    guid: Mapped[UUID] = mapped_column(default=uuid4, unique=True, nullable=False)
    resource_type: Mapped[AttackResourceType] = mapped_column(
        SQLAEnum(AttackResourceType),
        default=AttackResourceType.WORD_LIST,
        nullable=False,
    )
    # NOTE: Alembic migration required for new resource_type column.

    def __repr__(self) -> str:
        return f"<AttackResourceFile(id={self.id}, file_name={self.file_name}, resource_type={self.resource_type})>"

    # TODO: Phase 2b - resource management: re-enable these relationships when Attack model fields are present
