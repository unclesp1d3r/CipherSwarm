from __future__ import annotations

from sqlalchemy import Column, ForeignKey, Integer, String, Table
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base
from app.models.hash_item import HashItem

# Association table for many-to-many relationship between HashList and HashItem
hash_list_items = Table(
    "hash_list_items",
    Base.metadata,
    Column("hash_list_id", Integer, ForeignKey("hash_lists.id"), primary_key=True),
    Column("hash_item_id", Integer, ForeignKey("hash_items.id"), primary_key=True),
)


class HashList(Base):
    """Model for a list of hashes targeted by a campaign/attack."""

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(String(512), nullable=True)
    project_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("projects.id"), nullable=False, index=True
    )
    hash_type_id: Mapped[int] = mapped_column(
        ForeignKey("hash_types.id"), nullable=False, index=True
    )
    hash_type = relationship("HashType")
    # Many-to-many relationship to HashItem
    items = relationship(
        "HashItem", secondary=hash_list_items, back_populates="hash_lists"
    )
    # created_at and updated_at are inherited from Base

    @property
    def cracked_hashes(self) -> list[HashItem]:
        """
        Returns all HashItems in this HashList that have a non-null plain_text (i.e., cracked).
        Legacy contract: see legacy hash_list.rb and algorithm_implementation_guide.md.
        """
        return [item for item in self.items if getattr(item, "plain_text", None)]

    @property
    def uncracked_hashes(self) -> list[HashItem]:
        """
        Returns all HashItems in this HashList that do not have a plain_text (i.e., uncracked).
        """
        return [item for item in self.items if not getattr(item, "plain_text", None)]

    @property
    def cracked_count(self) -> int:
        """
        Returns the number of cracked hashes in this HashList.
        """
        return len(self.cracked_hashes)

    @property
    def uncracked_count(self) -> int:
        """
        Returns the number of uncracked hashes in this HashList.
        """
        return len(self.uncracked_hashes)
