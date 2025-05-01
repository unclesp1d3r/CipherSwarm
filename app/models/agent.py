from datetime import datetime
from enum import Enum
from typing import List

from sqlalchemy import JSON, String, Enum as SQLAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class AgentState(str, Enum):
    """Enum for agent states."""

    PENDING = "pending"
    ACTIVE = "active"
    STOPPED = "stopped"
    ERROR = "error"


class Agent(Base):
    """Model for agent instances."""

    host_name: Mapped[str] = mapped_column(String(255), nullable=False)
    client_signature: Mapped[str] = mapped_column(String(255), nullable=False)
    operating_system: Mapped[str] = mapped_column(String(255), nullable=False)
    state: Mapped[AgentState] = mapped_column(
        SQLAEnum(AgentState), default=AgentState.PENDING, nullable=False
    )
    devices: Mapped[List[str]] = mapped_column(JSON, default=list)
    last_seen_at: Mapped[datetime] = mapped_column(nullable=True, default=None)
    advanced_configuration: Mapped[dict] = mapped_column(
        JSON,
        default=lambda: {
            "agent_update_interval": 30,
            "use_native_hashcat": False,
            "backend_device": None,
            "opencl_devices": None,
            "enable_additional_hash_types": False,
        },
    )

    # Relationships
    tasks = relationship("Task", back_populates="agent")
    benchmarks = relationship("HashcatBenchmark", back_populates="agent")
