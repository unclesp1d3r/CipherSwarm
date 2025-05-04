from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field

from app.models.task import TaskStatus


class TaskBase(BaseModel):
    status: TaskStatus = TaskStatus.PENDING
    stale: bool = False
    start_date: datetime
    end_date: datetime | None = None
    completed_at: datetime | None = None
    progress_percent: float = 0.0
    progress_keyspace: int = 0
    result_json: dict[str, Any] | None = None
    agent_id: UUID | None = None
    attack_id: int


class TaskCreate(TaskBase):
    pass


class TaskUpdate(BaseModel):
    status: TaskStatus | None = None
    stale: bool | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    completed_at: datetime | None = None
    progress_percent: float | None = None
    progress_keyspace: int | None = None
    result_json: dict[str, Any] | None = None
    agent_id: UUID | None = None
    attack_id: int | None = None


class TaskOut(TaskBase):
    id: int

    class Config:
        from_attributes = True


class TaskProgressUpdate(BaseModel):
    progress_percent: float = Field(
        ..., ge=0.0, le=100.0, description="Task progress as a percentage (0-100)"
    )
    keyspace_processed: int = Field(
        ..., ge=0, description="Number of keyspace units processed so far"
    )


class TaskResultSubmit(BaseModel):
    cracked_hashes: list[dict[str, Any]] = Field(
        ..., description="List of cracked hashes and their plaintexts"
    )
    metadata: dict[str, Any] | None = Field(
        None, description="Additional result metadata (e.g., runtime, device info)"
    )
    error: str | None = Field(None, description="Error message if the task failed")


class HashcatResult(BaseModel):
    timestamp: datetime = Field(..., description="The time the hash was cracked")
    hash: str = Field(..., description="The hash value")
    plain_text: str = Field(..., description="The plain text value")
