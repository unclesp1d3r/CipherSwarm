from datetime import datetime
from typing import Annotated, Any

from pydantic import BaseModel, ConfigDict, Field

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
    agent_id: int | None = None
    attack_id: int
    skip: int | None = None
    limit: int | None = None


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
    agent_id: int | None = None
    attack_id: int | None = None


class TaskOut(TaskBase):
    id: int

    model_config = ConfigDict(from_attributes=True)


class TaskOutV1(BaseModel):
    id: Annotated[int, Field(..., description="The id of the task")]
    attack_id: Annotated[int, Field(..., description="The id of the attack")]
    start_date: Annotated[
        datetime, Field(..., description="The time the task was started")
    ]
    status: Annotated[str, Field(..., description="The status of the task")]
    skip: Annotated[
        int | None, Field(default=None, description="The offset of the keyspace")
    ]
    limit: Annotated[
        int | None, Field(default=None, description="The limit of the keyspace")
    ]
    model_config = ConfigDict(extra="forbid", from_attributes=True)


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
    timestamp: Annotated[
        datetime, Field(..., description="The time the hash was cracked")
    ]
    hash: Annotated[str, Field(..., description="The hash value")]
    plain_text: Annotated[str, Field(..., description="The plain text value")]
    model_config = ConfigDict(extra="forbid")
