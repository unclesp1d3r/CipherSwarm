from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class AgentDevicePerformance(Base):
    """
    Stores time series performance data (guesses/sec) for each device on each agent.
    """

    __tablename__ = "agent_device_performance"  # type: ignore[assignment]
    __table_args__ = (
        Index("ix_agent_device_time", "agent_id", "device_name", "timestamp"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    agent_id: Mapped[int] = mapped_column(
        ForeignKey("agents.id"), nullable=False, index=True
    )
    device_name: Mapped[str] = mapped_column(String(length=128), nullable=False)
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, index=True
    )
    speed: Mapped[float] = mapped_column(Float, nullable=False)

    agent = relationship("Agent", backref="device_performance")
