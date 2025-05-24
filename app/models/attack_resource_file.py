from enum import Enum
from uuid import UUID, uuid4

from sqlalchemy import JSON, String
from sqlalchemy import Enum as SQLAEnum
from sqlalchemy.ext.mutable import MutableDict
from sqlalchemy.orm import Mapped, mapped_column

from app.models.attack import AttackMode
from app.models.base import Base


class AttackResourceType(str, Enum):
    MASK_LIST = "mask_list"
    RULE_LIST = "rule_list"
    WORD_LIST = "word_list"
    CHARSET = "charset"
    DYNAMIC_WORD_LIST = "dynamic_word_list"
    EPHEMERAL_WORD_LIST = "ephemeral_word_list"  # For inline, attack-scoped wordlists
    EPHEMERAL_MASK_LIST = "ephemeral_mask_list"  # For inline, attack-scoped mask lists
    EPHEMERAL_RULE_LIST = "ephemeral_rule_list"  # For inline, attack-scoped rule lists


class AttackResourceFile(Base):
    """Model for attack resource files (wordlists, rules, masks)."""

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    project_id: Mapped[int | None] = mapped_column(nullable=True)
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    download_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    checksum: Mapped[str] = mapped_column(String(64), nullable=False)
    guid: Mapped[UUID] = mapped_column(default=uuid4, unique=True, nullable=False)
    resource_type: Mapped[AttackResourceType] = mapped_column(
        SQLAEnum(AttackResourceType),
        default=AttackResourceType.WORD_LIST,
        nullable=False,
    )
    line_format: Mapped[str] = mapped_column(
        String(32), nullable=False, default="freeform"
    )
    line_encoding: Mapped[str] = mapped_column(
        String(16), nullable=False, default="utf-8"
    )
    used_for_modes: Mapped[list[AttackMode]] = mapped_column(
        JSON, default=list, nullable=False
    )
    source: Mapped[str] = mapped_column(String(32), nullable=False, default="upload")
    line_count: Mapped[int] = mapped_column(nullable=False, default=0)
    byte_size: Mapped[int] = mapped_column(nullable=False, default=0)
    # New: JSON content for ephemeral/dynamic resources (e.g., inline wordlists, masks)
    content: Mapped[dict[str, object] | None] = mapped_column(
        MutableDict.as_mutable(JSON), nullable=True, default=None
    )
    # NOTE: Alembic migration required for new resource_type column, metadata columns, and line_count and byte_size columns.

    def __repr__(self) -> str:
        return (
            f"<AttackResourceFile(id={self.id}, file_name={self.file_name}, resource_type={self.resource_type}, "
            f"line_format={self.line_format}, line_encoding={self.line_encoding}, used_for_modes={[m.value for m in self.used_for_modes]}, source={self.source}, "
            f"line_count={self.line_count}, byte_size={self.byte_size})>"
        )

    # TODO: Phase 2b - resource management: re-enable these relationships when Attack model fields are present
