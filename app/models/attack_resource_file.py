from uuid import UUID, uuid4

from sqlalchemy import String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class AttackResourceFile(Base):
    """Model for attack resource files (wordlists, rules, masks)."""

    id: Mapped[UUID] = mapped_column(primary_key=True, default=uuid4)
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    download_url: Mapped[str] = mapped_column(String(1024), nullable=False)
    checksum: Mapped[str] = mapped_column(String(64), nullable=False)

    # Relationships for different uses of the resource file
    # word_list_attacks = relationship(
    #     "Attack", back_populates="word_list", foreign_keys="[Attack.word_list_id]"
    # )
    # rule_list_attacks = relationship(
    #     "Attack", back_populates="rule_list", foreign_keys="[Attack.rule_list_id]"
    # )
    # mask_list_attacks = relationship(
    #     "Attack", back_populates="mask_list", foreign_keys="[Attack.mask_list_id]"
    # )
    # TODO: Phase 3 - resource management: re-enable these relationships when Attack model fields are present
