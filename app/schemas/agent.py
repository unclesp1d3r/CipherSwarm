"""Pydantic schemas for the Agent model in CipherSwarm."""

from datetime import datetime
from typing import Annotated, Any
from uuid import UUID

from fastapi import Form
from pydantic import AnyHttpUrl, BaseModel, Field, field_validator
from pydantic.config import ConfigDict

from app.models.agent import AgentState, AgentType, OperatingSystemEnum


class AdvancedAgentConfiguration(BaseModel):
    """Schema for advanced agent configuration."""

    agent_update_interval: Annotated[
        int | None,
        Field(
            default=30, description="The interval in seconds to check for agent updates"
        ),
    ]
    use_native_hashcat: Annotated[
        bool | None,
        Field(
            default=False,
            description="Use the hashcat binary already installed on the client system",
        ),
    ]
    backend_device: Annotated[
        str | None,
        Field(
            default=None,
            description="The device to use for hashcat, separated by commas",
        ),
    ]
    opencl_devices: Annotated[
        str | None,
        Field(
            default=None,
            description="The OpenCL device types to use for hashcat, separated by commas",
        ),
    ]
    enable_additional_hash_types: Annotated[
        bool,
        Field(
            default=False,
            description=(
                "Causes hashcat to perform benchmark-all, rather than just benchmark"
            ),
        ),
    ]


class AgentBase(BaseModel):
    """Base schema for Agent."""

    host_name: Annotated[str, Field(..., description="The hostname of the agent")]
    client_signature: Annotated[
        str, Field(..., description="The signature of the client")
    ]
    operating_system: Annotated[
        OperatingSystemEnum, Field(..., description="The operating system of the agent")
    ]
    devices: Annotated[
        list[str],
        Field(..., description="The descriptive name of a GPU or CPU device."),
    ]
    state: Annotated[AgentState, Field(..., description="The state of the agent")]
    advanced_configuration: Annotated[
        "AdvancedAgentConfiguration",
        Field(..., description="The advanced configuration of the agent"),
    ]

    model_config = ConfigDict(from_attributes=True)


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
    advanced_configuration: dict[str, Any] | None = None
    devices: list[str] | None = None
    agent_type: AgentType | None = None
    operating_system: OperatingSystemEnum
    user_id: UUID | None = None
    projects: list[UUID]
    created_at: datetime
    updated_at: datetime


class AgentCreate(BaseModel):
    """Schema for creating a new agent."""

    client_signature: Annotated[
        str, Field(..., description="The signature of the client")
    ]
    host_name: Annotated[str, Field(..., description="The hostname of the agent")]
    custom_label: str | None = None
    token: str
    last_seen_at: datetime | None = None
    last_ipaddress: str | None = None
    state: AgentState
    enabled: bool = True
    advanced_configuration: dict[str, Any] | None = None
    devices: list[str] | None = None
    agent_type: AgentType | None = None
    operating_system: OperatingSystemEnum
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
    advanced_configuration: dict[str, Any] | None = None
    devices: list[str] | None = None
    agent_type: AgentType | None = None
    operating_system: OperatingSystemEnum | None = None
    user_id: UUID | None = None
    projects: list[UUID] | None = None


class AgentResponse(AgentBase):
    """Schema for agent response."""

    id: Annotated[int, Field(..., description="The id of the agent")]
    state: Annotated[AgentState, Field(..., description="The state of the agent")]
    advanced_configuration: Annotated[
        AdvancedAgentConfiguration,
        Field(..., description="The advanced configuration of the agent"),
    ]
    created_at: datetime
    updated_at: datetime
    last_seen_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class HashcatBenchmark(BaseModel):
    """Schema for hashcat benchmark results."""

    hash_type: Annotated[int, Field(..., description="The hashcat hash type")]
    runtime: Annotated[
        int, Field(..., description="The runtime of the benchmark in milliseconds")
    ]
    hash_speed: Annotated[
        float, Field(..., description="The speed of the benchmark in hashes per second")
    ]
    device: Annotated[int, Field(..., description="The device used for the benchmark")]


class AgentBenchmark(BaseModel):
    """Schema for agent benchmark submission."""

    hashcat_benchmarks: list[HashcatBenchmark]


class AgentError(BaseModel):
    """Schema for agent error submission."""

    message: Annotated[str, Field(..., description="The error message")]
    severity: Annotated[
        str,
        Field(
            ...,
            description="The severity of the error",
            pattern="^(info|warning|minor|major|critical|fatal)$",
        ),
    ]
    metadata: Annotated[
        dict[str, Any] | None,
        Field(default=None, description="Additional metadata about the error"),
    ]


# Registration request/response schemas for agent registration
class AgentRegisterRequest(BaseModel):
    signature: Annotated[str, Field(..., description="Unique agent signature")]
    hostname: Annotated[str, Field(..., description="Agent hostname")]
    agent_type: Annotated[
        AgentType,
        Field(..., description="Type of agent (physical, virtual, container)"),
    ]
    operating_system: Annotated[
        OperatingSystemEnum, Field(..., description="The operating system of the agent")
    ]
    model_config = ConfigDict()


class AgentRegisterResponse(BaseModel):
    agent_id: Annotated[int, Field(..., description="Registered agent id")]
    token: Annotated[
        str,
        Field(..., description="Agent authentication token (csa_<agent_id>_<token>"),
    ]


class AgentStateUpdateRequest(BaseModel):
    state: Annotated[
        AgentState,
        Field(default=..., description="New agent state", examples=["active"]),
    ]


class AgentHeartbeatRequest(BaseModel):
    state: Annotated[
        AgentState,
        Field(..., description="Current agent state"),
    ]


class CrackerBinaryOut(BaseModel):
    id: int
    operating_system: str
    version: str
    download_url: str
    exec_name: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class AgentResponseV1(BaseModel):
    id: Annotated[int, Field(..., description="The id of the agent")]
    host_name: Annotated[str, Field(..., description="The hostname of the agent")]
    client_signature: Annotated[
        str, Field(..., description="The signature of the client")
    ]
    operating_system: Annotated[
        str, Field(..., description="The operating system of the agent")
    ]
    devices: Annotated[
        list[str],
        Field(..., description="The descriptive name of a GPU or CPU device."),
    ]
    state: Annotated[
        str, Field(..., description="The state of the agent")
    ]  # must be str for OpenAPI enum
    advanced_configuration: Annotated[
        "AdvancedAgentConfiguration",
        Field(..., description="The advanced configuration of the agent"),
    ]
    model_config = ConfigDict(from_attributes=True, extra="forbid")


class AgentUpdateV1(BaseModel):
    id: Annotated[int, Field(..., description="The id of the agent")]
    host_name: Annotated[str, Field(..., description="The hostname of the agent")]
    client_signature: Annotated[
        str, Field(..., description="The signature of the client")
    ]
    operating_system: Annotated[
        str, Field(..., description="The operating system of the agent")
    ]
    devices: Annotated[
        list[str],
        Field(..., description="The descriptive name of a GPU or CPU device."),
    ]
    model_config = ConfigDict(extra="forbid")


class AgentErrorV1(BaseModel):
    message: Annotated[str, Field(..., description="The error message")]
    severity: Annotated[
        str,
        Field(
            ...,
            description="The severity of the error",
            pattern="^(info|warning|minor|major|critical|fatal)$",
        ),
    ]
    agent_id: Annotated[int, Field(..., description="The agent that caused the error")]
    metadata: Annotated[
        dict[str, Any] | None,
        Field(default=None, description="Additional metadata about the error"),
    ]
    task_id: Annotated[
        int | None,
        Field(default=None, description="The task that caused the error, if any"),
    ]
    model_config = ConfigDict(extra="forbid")


class AgentPresignedUrlTestRequest(BaseModel):
    url: Annotated[
        AnyHttpUrl, Field(..., description="The presigned S3/MinIO URL to test")
    ]

    @field_validator("url")
    @classmethod
    def validate_scheme(cls, v: AnyHttpUrl) -> AnyHttpUrl:
        if v.scheme not in ("http", "https"):
            raise ValueError("Only http and https URLs are allowed")
        return v


class AgentPresignedUrlTestResponse(BaseModel):
    valid: bool


class DevicePerformancePoint(BaseModel):
    """A single time series point for device performance."""

    timestamp: Annotated[
        datetime, Field(description="UTC timestamp for the measurement")
    ]
    speed: Annotated[float, Field(description="Guesses/sec at this timestamp")]


class DevicePerformanceSeries(BaseModel):
    """Time series for a single device on an agent."""

    device: Annotated[str, Field(description="Device name as reported by agent")]
    data: Annotated[
        list[DevicePerformancePoint], Field(description="Time series data points")
    ]


class AgentRegisterForm(BaseModel):
    host_name: Annotated[str, Form(..., description="Agent host name")]
    operating_system: Annotated[
        str, Form(..., description="Operating system")
    ]  # Will be mapped to enum in service
    client_signature: Annotated[str, Form(..., description="Client signature")]
    custom_label: Annotated[str | None, Form(None, description="Custom label")]
    devices: Annotated[
        str | None, Form(None, description="Comma-separated device list")
    ]
    agent_update_interval: Annotated[
        int | None, Form(30, description="Update interval (seconds)")
    ]
    use_native_hashcat: Annotated[
        bool | None, Form(False, description="Use native hashcat")
    ]
    backend_device: Annotated[
        str | None, Form(None, description="Backend device override")
    ]
    opencl_devices: Annotated[
        str | None, Form(None, description="OpenCL devices override")
    ]
    enable_additional_hash_types: Annotated[
        bool | None, Form(False, description="Enable additional hash types")
    ]


class AgentOut(BaseModel):
    id: int
    host_name: str
    client_signature: str
    custom_label: str | None = None
    state: AgentState
    enabled: bool
    advanced_configuration: dict[str, Any] | None = None
    devices: list[str] | None = None
    agent_type: AgentType | None = None
    operating_system: OperatingSystemEnum
    created_at: datetime
    updated_at: datetime
    last_seen_at: datetime | None = None
    last_ipaddress: str | None = None
    projects: list[Any] = []
    model_config = ConfigDict(from_attributes=True)


class AgentRegisterModalContext(BaseModel):
    agent: AgentOut
    token: str


__all__ = [
    "AgentOut",
]
