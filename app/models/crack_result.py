from sqlalchemy import ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column

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
        Integer, ForeignKey("hashitems.id"), nullable=False, index=True
    )
