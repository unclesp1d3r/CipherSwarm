"""OperatingSystem model for CipherSwarm agent platform support."""

import enum

from sqlalchemy import Enum, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class OSName(enum.Enum):
    """Enum for supported operating system names."""

    windows = "windows"
    linux = "linux"
    darwin = "darwin"


class OperatingSystem(Base):
    """Represents an operating system supported by CipherSwarm agents."""

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[OSName] = mapped_column(
        Enum(OSName), unique=True, nullable=False, index=True
    )
    cracker_command: Mapped[str] = mapped_column(String(length=256), nullable=False)
