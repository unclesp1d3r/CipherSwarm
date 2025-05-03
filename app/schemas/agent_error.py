"""Pydantic schemas for the AgentError model in CipherSwarm."""

from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.agent_error import Severity


class AgentErrorBase(BaseModel):
    """Base schema for AgentError."""

    message: str = Field(..., description="The error message reported by the agent")
    severity: Severity = Field(..., description="The severity of the error")
    error_code: str | None = Field(
        default=None, description="Optional error code for programmatic handling"
    )
    details: dict[str, Any] | None = Field(
        default=None,
        description="Optional structured data with additional error context",
    )
    agent_id: UUID = Field(..., description="ID of the reporting agent")
    task_id: UUID | None = Field(
        default=None, description="ID of the related task, if applicable"
    )


class AgentErrorCreate(AgentErrorBase):
    """Schema for creating a new AgentError."""


class AgentErrorUpdate(BaseModel):
    """Schema for updating an AgentError."""

    message: str | None = Field(
        default=None, description="The error message reported by the agent"
    )
    severity: Severity | None = Field(
        default=None, description="The severity of the error"
    )
    error_code: str | None = Field(
        default=None, description="Optional error code for programmatic handling"
    )
    details: dict[str, Any] | None = Field(
        default=None,
        description="Optional structured data with additional error context",
    )
    task_id: UUID | None = Field(
        default=None, description="ID of the related task, if applicable"
    )


class AgentErrorOut(AgentErrorBase):
    """Schema for reading AgentError data."""

    id: UUID
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
