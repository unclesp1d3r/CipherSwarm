"""Pydantic schemas for the Agent model in CipherSwarm."""

from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.agent import AgentState, AgentType


class AdvancedAgentConfiguration(BaseModel):
    """Schema for advanced agent configuration."""

    agent_update_interval: int | None = Field(
        default=30, description="The interval in seconds to check for agent updates"
    )
    use_native_hashcat: bool | None = Field(
        default=False,
        description="Use the hashcat binary already installed on the client system",
    )
    backend_device: str | None = Field(
        default=None, description="The device to use for hashcat, separated by commas"
    )
    opencl_devices: str | None = Field(
        default=None,
        description="The OpenCL device types to use for hashcat, separated by commas",
    )
    enable_additional_hash_types: bool = Field(
        default=False,
        description=(
            "Causes hashcat to perform benchmark-all, rather than just benchmark"
        ),
    )


class AgentBase(BaseModel):
    """Base schema for Agent."""

    host_name: str = Field(..., description="The hostname of the agent")
    client_signature: str = Field(..., description="The signature of the client")
    operating_system: str = Field(..., description="The operating system of the agent")
    devices: list[str] = Field(
        ..., description="The descriptive names of GPU or CPU devices"
    )


class AgentRead(BaseModel):
    """Schema for reading agent data."""

    id: UUID
    client_signature: str
    host_name: str
    custom_label: str | None = None
    token: str
    last_seen_at: datetime | None = None
    last_ipaddress: str | None = None
    state: AgentState
    enabled: bool
    advanced_configuration: dict | None = None
    devices: list | None = None
    agent_type: AgentType | None = None
    operating_system_id: UUID
    user_id: UUID | None = None
    projects: list[UUID]
    created_at: datetime
    updated_at: datetime


class AgentCreate(BaseModel):
    """Schema for creating a new agent."""

    client_signature: str
    host_name: str
    custom_label: str | None = None
    token: str
    last_seen_at: datetime | None = None
    last_ipaddress: str | None = None
    state: AgentState
    enabled: bool = True
    advanced_configuration: dict | None = None
    devices: list | None = None
    agent_type: AgentType | None = None
    operating_system_id: UUID
    user_id: UUID | None = None
    projects: list[UUID] | None = None


class AgentUpdate(BaseModel):
    """Schema for updating agent data."""

    client_signature: str | None = None
    host_name: str | None = None
    custom_label: str | None = None
    token: str | None = None
    last_seen_at: datetime | None = None
    last_ipaddress: str | None = None
    state: AgentState | None = None
    enabled: bool | None = None
    advanced_configuration: dict | None = None
    devices: list | None = None
    agent_type: AgentType | None = None
    operating_system_id: UUID | None = None
    user_id: UUID | None = None
    projects: list[UUID] | None = None


class AgentResponse(AgentBase):
    """Schema for agent response."""

    id: int = Field(..., description="The id of the agent")
    state: AgentState = Field(..., description="The state of the agent")
    advanced_configuration: AdvancedAgentConfiguration
    created_at: datetime
    updated_at: datetime
    last_seen_at: datetime | None = None

    class Config:
        """Pydantic config."""

        from_attributes = True


class HashcatBenchmark(BaseModel):
    """Schema for hashcat benchmark results."""

    hash_type: int = Field(..., description="The hashcat hash type")
    runtime: int = Field(
        ..., description="The runtime of the benchmark in milliseconds"
    )
    hash_speed: float = Field(
        ..., description="The speed of the benchmark in hashes per second"
    )
    device: int = Field(..., description="The device used for the benchmark")


class AgentBenchmark(BaseModel):
    """Schema for agent benchmark submission."""

    hashcat_benchmarks: list[HashcatBenchmark]


class AgentError(BaseModel):
    """Schema for agent error submission."""

    message: str = Field(..., description="The error message")
    severity: str = Field(
        ...,
        description="The severity of the error",
        pattern="^(info|warning|minor|major|critical|fatal)$",
    )
    metadata: dict | None = Field(
        default=None, description="Additional metadata about the error"
    )
