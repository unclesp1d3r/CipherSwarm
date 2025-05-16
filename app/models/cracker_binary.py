from datetime import datetime

from sqlalchemy import DateTime, Enum, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.agent import OperatingSystemEnum
from app.models.base import Base


class CrackerBinary(Base):
    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    operating_system: Mapped[OperatingSystemEnum] = mapped_column(
        Enum(OperatingSystemEnum), nullable=False, index=True
    )
    version: Mapped[str] = mapped_column(String(length=32), nullable=False)
    download_url: Mapped[str] = mapped_column(String(length=512), nullable=False)
    exec_name: Mapped[str] = mapped_column(String(length=128), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=datetime.now, nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=datetime.now,
        onupdate=datetime.now,
        nullable=False,
    )
