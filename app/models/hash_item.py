from sqlalchemy import JSON, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class HashItem(Base):
    """Model for an individual hash in a hash list."""

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    hash: Mapped[str] = mapped_column(String(512), nullable=False)
    salt: Mapped[str | None] = mapped_column(String(512), nullable=True)
    meta: Mapped[dict[str, str] | None] = mapped_column(JSON, nullable=True)
    # Legacy contract: cracked hashes are those with non-null plain_text (see legacy hash_item.rb)
    plain_text: Mapped[str | None] = mapped_column(String(512), nullable=True)
    # Many-to-many relationship to HashList
    hash_lists = relationship(
        "HashList", secondary="hash_list_items", back_populates="items"
    )
    # created_at and updated_at are inherited from Base
    __table_args__ = (UniqueConstraint("hash", "salt", name="uq_hashitem_hash_salt"),)
