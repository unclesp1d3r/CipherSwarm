from sqlalchemy import ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class CrackResult(Base):
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    agent_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("agents.id"), nullable=False, index=True
    )
    attack_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("attacks.id"), nullable=False, index=True
    )
    hash_item_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("hash_items.id"), nullable=False, index=True
    )

    # Relationships
    agent = relationship("Agent", back_populates="crack_results")
    attack = relationship("Attack", back_populates="crack_results")
    hash_item = relationship("HashItem", back_populates="crack_results")
