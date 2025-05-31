from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, Index, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base


class AgentDevicePerformance(Base):
    """
    Stores time series performance data (guesses/sec) for each device on each agent.

    Fields:
        - id (int): The ID of the agent device performance record.
        - agent_id (int): The ID of the agent that the performance data belongs to.
        - device_name (str): The name of the device that the performance data belongs to.
        - timestamp (datetime): The timestamp of the performance data.
        - speed (float): The speed of the device in guesses/sec.

    Notes:
        - The `agent_id` and `device_name` fields are used to identify the unique combination of agent and device.
        - The `timestamp` field is the timestamp of the performance data. It is the moment the performance data was submitted by the agent.
        - The `speed` field is the speed of the device in guesses/sec.
        - The `agent` field is a relationship to the `Agent` model.
        - The `device_name` field is the name of the device hardware (such as the specific CPU or GPU in the agent) that the performance data belongs to. It is a string column that stores the name of the device.
    """

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
