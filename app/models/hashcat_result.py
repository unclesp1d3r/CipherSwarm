# TODO: Phase 4 - implement when result ingestion is built
# from datetime import datetime
#
# from sqlalchemy import Integer, String, ForeignKey
# from sqlalchemy.orm import Mapped, mapped_column, relationship
#
# from app.models.base import Base
#
#
# class HashcatResult(Base):
#     """Model for hashcat cracking results."""
#
#     task_id: Mapped[int] = mapped_column(
#         Integer, ForeignKey("tasks.id"), nullable=False
#     )
#     timestamp: Mapped[datetime] = mapped_column(nullable=False)
#     hash_value: Mapped[str] = mapped_column(
#         String(1024),
#         nullable=False,
#         name="hash",  # Using name="hash" as hash is a Python built-in
#     )
#     plain_text: Mapped[str] = mapped_column(String(1024), nullable=False)
#
#     # Relationship
#     task = relationship("Task", back_populates="results")
