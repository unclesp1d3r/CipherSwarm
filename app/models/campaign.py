from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class Campaign(Base):
    """Campaign model: operational grouping under a Project. Each campaign is associated with a required HashList."""

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(length=128), nullable=False, index=True)
    description: Mapped[str | None] = mapped_column(String(length=512), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow
    )
    project_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("projects.id"), nullable=False, index=True
    )
    priority: Mapped[int] = mapped_column(default=0, nullable=False)
    hash_list_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("hashlists.id"), nullable=False, index=True
    )

    hash_list = relationship("HashList")
    project = relationship("Project", back_populates="campaigns")
    attacks = relationship("Attack", back_populates="campaign", lazy="selectin")

    @property
    def progress_percent(self) -> float:
        attacks = self.attacks or []
        if not attacks:
            return 0.0
        return float(sum(a.progress_percent for a in attacks)) / float(len(attacks))

    @property
    def is_complete(self) -> bool:
        attacks = self.attacks or []
        if not attacks:
            return False
        return all(a.is_complete for a in attacks)
