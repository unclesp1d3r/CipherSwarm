"""
Agent API v2 Schema Foundation

This module contains all v2-specific schemas for the Agent API.
These schemas are designed to be forward-compatible and provide
improved functionality over the v1 API while maintaining clean
separation from legacy schemas.
"""

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, Field

# Import base types from existing schemas
from app.models.agent import AgentState
from app.models.task import TaskStatus

# ============================================================================
# V2-Specific Enums
# ============================================================================


class TaskPriorityV2(str, Enum):
    """Task priority levels for API v2."""

    LOW = "low"
    MEDIUM = "medium"
    HIGH = "high"
    CRITICAL = "critical"


# ============================================================================
# Agent Registration Schemas (v2)
# ============================================================================


class AgentRegisterRequestV2(BaseModel):
    """Request schema for agent registration in API v2."""

    signature: str = Field(
        ...,
        description="Agent signature for identification",
        min_length=1,
        max_length=255,
    )
    hostname: str = Field(
        ..., description="Hostname of the agent machine", min_length=1, max_length=255
    )
    agent_type: str = Field(
        ...,
        description="Type of agent (e.g., 'hashcat', 'john', 'custom')",
        min_length=1,
        max_length=50,
    )
    operating_system: str = Field(
        ..., description="Operating system of the agent", min_length=1, max_length=100
    )
    capabilities: dict[str, Any] | None = Field(
        None, description="Agent capabilities and metadata"
    )
    version: str | None = Field(None, description="Agent version", max_length=50)


class AgentRegisterResponseV2(BaseModel):
    """Response schema for successful agent registration in API v2."""

    agent_id: str = Field(..., description="Unique agent identifier")
    token: str = Field(..., description="Authentication token for the agent")
    expires_at: datetime | None = Field(None, description="Token expiration time")
    server_version: str = Field(..., description="Server API version")
    heartbeat_interval: int = Field(
        30, description="Recommended heartbeat interval in seconds"
    )


# ============================================================================
# Agent Heartbeat Schemas (v2)
# ============================================================================


class AgentHeartbeatRequestV2(BaseModel):
    """Request schema for agent heartbeat in API v2."""

    state: AgentState = Field(..., description="Current agent state")
    cpu_usage: float | None = Field(
        None, ge=0, le=100, description="CPU usage percentage"
    )
    memory_usage: float | None = Field(
        None, ge=0, le=100, description="Memory usage percentage"
    )
    active_tasks: int | None = Field(
        None, ge=0, description="Number of currently active tasks"
    )
    metadata: dict[str, Any] | None = Field(
        None, description="Additional heartbeat metadata"
    )


class AgentHeartbeatResponseV2(BaseModel):
    """Response schema for agent heartbeat in API v2."""

    status: str = Field("ok", description="Heartbeat acknowledgment status")
    timestamp: datetime = Field(..., description="Server timestamp")
    agent_id: str = Field(..., description="Agent identifier")
    instructions: dict[str, Any] | None = Field(
        None, description="Server instructions for the agent"
    )
    next_heartbeat_in: int = Field(
        30, description="Seconds until next heartbeat is expected"
    )


# ============================================================================
# Task Assignment Schemas (v2)
# ============================================================================


class TaskAssignmentResponseV2(BaseModel):
    """Response schema for task assignment in API v2."""

    task_id: str = Field(..., description="Unique task identifier")
    attack_id: str = Field(..., description="Associated attack identifier")

    # Task details
    task_type: str = Field(..., description="Type of task")
    priority: TaskPriorityV2 = Field(TaskPriorityV2.MEDIUM, description="Task priority")

    # Keyspace chunk information
    keyspace_start: int = Field(..., description="Starting keyspace position")
    keyspace_end: int = Field(..., description="Ending keyspace position")
    skip: int | None = Field(None, description="Skip value for keyspace")
    limit: int | None = Field(None, description="Limit value for keyspace")

    # Resource references
    hash_file_id: int | None = Field(None, description="Hash file resource ID")
    dictionary_ids: list[int] | None = Field(
        None, description="Dictionary resource IDs"
    )
    rule_ids: list[int] | None = Field(None, description="Rule file resource IDs")

    # Execution parameters
    timeout: int | None = Field(None, description="Task timeout in seconds")
    estimated_duration: int | None = Field(
        None, description="Estimated task duration in seconds"
    )


# ============================================================================
# Progress Tracking Schemas (v2)
# ============================================================================


class TaskProgressUpdateV2(BaseModel):
    """Schema for task progress updates in API v2."""

    progress_percent: float = Field(
        ..., ge=0, le=100, description="Task completion percentage"
    )
    keyspace_processed: int | None = Field(
        None, description="Amount of keyspace processed"
    )
    current_speed: float | None = Field(
        None, description="Current processing speed (hashes/second)"
    )
    estimated_completion: datetime | None = Field(
        None, description="Estimated completion time"
    )
    status: TaskStatus | None = Field(None, description="Updated task status")
    message: str | None = Field(None, description="Progress message or status update")


class TaskProgressResponseV2(BaseModel):
    """Response schema for task progress updates in API v2."""

    task_id: str = Field(..., description="Task identifier")
    status: str = Field("updated", description="Update acknowledgment status")
    timestamp: datetime = Field(..., description="Server timestamp")
    next_update_in: int | None = Field(
        None, description="Recommended seconds until next progress update"
    )


# ============================================================================
# Result Submission Schemas (v2)
# ============================================================================


class CrackedHashV2(BaseModel):
    """Schema for individual cracked hash in API v2."""

    hash_value: str = Field(..., description="The cracked hash")
    plaintext: str = Field(..., description="The discovered plaintext")
    crack_time: datetime = Field(..., description="When the hash was cracked")
    keyspace_position: int | None = Field(
        None, description="Keyspace position where hash was found"
    )


class TaskResultSubmissionV2(BaseModel):
    """Schema for task result submission in API v2."""

    task_id: str = Field(..., description="Task identifier")
    status: TaskStatus = Field(..., description="Final task status")

    # Results
    cracked_hashes: list[CrackedHashV2] = Field(
        default_factory=list, description="List of successfully cracked hashes"
    )

    # Execution metadata
    execution_time: float | None = Field(
        None, description="Total execution time in seconds"
    )
    keyspace_processed: int | None = Field(None, description="Total keyspace processed")
    final_speed: float | None = Field(
        None, description="Final processing speed (hashes/second)"
    )

    # Error information (if task failed)
    error_message: str | None = Field(None, description="Error message if task failed")
    error_code: str | None = Field(None, description="Error code if task failed")

    # Additional metadata
    metadata: dict[str, Any] | None = Field(
        None, description="Additional result metadata"
    )


class TaskResultResponseV2(BaseModel):
    """Response schema for task result submission in API v2."""

    task_id: str = Field(..., description="Task identifier")
    status: str = Field("accepted", description="Submission acknowledgment status")
    timestamp: datetime = Field(..., description="Server timestamp")
    results_processed: int = Field(..., description="Number of results processed")
    campaign_updated: bool = Field(
        False, description="Whether campaign statistics were updated"
    )


# ============================================================================
# Resource Management Schemas (v2)
# ============================================================================


class ResourceUrlRequestV2(BaseModel):
    """Request schema for resource URL generation in API v2."""

    resource_type: str | None = Field(
        None, description="Type of resource being requested"
    )
    verify_hash: bool = Field(True, description="Whether to require hash verification")


class ResourceUrlResponseV2(BaseModel):
    """Response schema for resource URL generation in API v2."""

    resource_id: int = Field(..., description="Resource identifier")
    download_url: str = Field(..., description="Presigned download URL")
    expires_at: datetime = Field(..., description="URL expiration time")

    # Verification information
    expected_hash: str | None = Field(
        None, description="Expected file hash for verification"
    )
    hash_algorithm: str = Field("sha256", description="Hash algorithm used")

    # File metadata
    file_size: int | None = Field(None, description="File size in bytes")
    content_type: str = Field(
        "application/octet-stream", description="File content type"
    )
    filename: str | None = Field(None, description="Original filename")


# ============================================================================
# Error Response Schemas (v2)
# ============================================================================


class ErrorResponseV2(BaseModel):
    """Standard error response schema for API v2."""

    error: str = Field(..., description="Error type or code")
    message: str = Field(..., description="Human-readable error message")
    details: dict[str, Any] | None = Field(None, description="Additional error details")
    timestamp: datetime = Field(..., description="Error timestamp")
    request_id: str | None = Field(None, description="Request identifier for tracking")


# ============================================================================
# Agent Information Schemas (v2)
# ============================================================================


class AgentInfoResponseV2(BaseModel):
    """Response schema for agent information in API v2."""

    agent_id: str = Field(..., description="Agent identifier")
    signature: str = Field(..., description="Agent signature")
    hostname: str = Field(..., description="Agent hostname")
    agent_type: str = Field(..., description="Agent type")
    operating_system: str = Field(..., description="Operating system")

    # Status information
    status: AgentState = Field(..., description="Current agent status")
    last_seen: datetime | None = Field(None, description="Last heartbeat time")

    # Capabilities and metadata
    capabilities: dict[str, Any] | None = Field(None, description="Agent capabilities")
    version: str | None = Field(None, description="Agent version")

    # Statistics
    total_tasks: int | None = Field(None, description="Total tasks completed")
    active_tasks: int | None = Field(None, description="Currently active tasks")

    # Registration information
    registered_at: datetime = Field(..., description="Registration timestamp")
    api_version: int = Field(2, description="API version being used")


# ============================================================================
# Attack Configuration Schemas (v2)
# ============================================================================


class AttackConfigurationResponseV2(BaseModel):
    """Response schema for attack configuration in API v2."""

    attack_id: int = Field(..., description="Attack identifier")
    attack_type: str = Field(..., description="Type of attack (e.g., 'dictionary', 'mask', 'hybrid')")
    hash_type: int = Field(..., description="Hash type identifier")
    hash_type_name: str = Field(..., description="Human-readable hash type name")

    # Attack parameters
    parameters: dict[str, Any] = Field(..., description="Attack-specific parameters")

    # Resource requirements
    required_resources: list[int] = Field(
        default_factory=list, description="List of required resource IDs"
    )

    # Execution configuration
    priority: TaskPriorityV2 = Field(TaskPriorityV2.MEDIUM, description="Attack priority")
    timeout: int | None = Field(None, description="Timeout in seconds")

    # Metadata
    description: str | None = Field(None, description="Attack description")
    created_at: datetime = Field(..., description="Attack creation timestamp")
    updated_at: datetime = Field(..., description="Last update timestamp")


# ============================================================================
# Agent Update Schemas (v2)
# ============================================================================


class AgentUpdateRequestV2(BaseModel):
    """Request schema for agent updates in API v2."""

    signature: str | None = Field(None, description="Updated agent signature")
    hostname: str | None = Field(None, description="Updated hostname")
    capabilities: dict[str, Any] | None = Field(
        None, description="Updated capabilities"
    )
    version: str | None = Field(None, description="Updated agent version")
    status: AgentState | None = Field(None, description="Updated status")


class AgentUpdateResponseV2(BaseModel):
    """Response schema for agent updates in API v2."""

    agent_id: str = Field(..., description="Agent identifier")
    status: str = Field("updated", description="Update acknowledgment status")
    timestamp: datetime = Field(..., description="Server timestamp")
    updated_fields: list[str] = Field(
        default_factory=list, description="List of fields that were updated"
    )
