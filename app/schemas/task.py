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


class DeviceStatus(BaseModel):
    device_id: Annotated[int, Field(..., description="The id of the device")]
    device_name: Annotated[str, Field(..., description="The name of the device")]
    device_type: Annotated[
        str, Field(..., description="The type of the device", examples=["CPU", "GPU"])
    ]
    speed: Annotated[int, Field(..., description="The speed of the device")]
    utilization: Annotated[int, Field(..., description="The utilization of the device")]
    temperature: Annotated[
        int,
        Field(..., description="The temperature of the device, or -1 if unmonitored."),
    ]
    model_config = ConfigDict(extra="forbid")


class HashcatGuess(BaseModel):
    guess_base: Annotated[
        str,
        Field(
            ..., description="The base value used for the guess (for example, the mask)"
        ),
    ]
    guess_base_count: Annotated[
        int, Field(..., description="The number of times the base value was used")
    ]
    guess_base_offset: Annotated[
        int, Field(..., description="The offset of the base value")
    ]
    guess_base_percentage: Annotated[
        float, Field(..., description="The percentage completion of the base value")
    ]
    guess_mod: Annotated[
        str,
        Field(
            ...,
            description="The modifier used for the guess (for example, the wordlist)",
        ),
    ]
    guess_mod_count: Annotated[
        int, Field(..., description="The number of times the modifier was used")
    ]
    guess_mod_offset: Annotated[
        int, Field(..., description="The offset of the modifier")
    ]
    guess_mod_percentage: Annotated[
        float, Field(..., description="The percentage completion of the modifier")
    ]
    guess_mode: Annotated[int, Field(..., description="The mode used for the guess")]
    model_config = ConfigDict(extra="forbid")


class TaskStatusUpdate(BaseModel):
    original_line: Annotated[
        str, Field(..., description="The original line from hashcat")
    ]
    time: Annotated[
        datetime, Field(..., description="The time the status was received")
    ]
    session: Annotated[str, Field(..., description="The session name")]
    hashcat_guess: Annotated[
        HashcatGuess, Field(..., description="The current guess context")
    ]
    status: Annotated[int, Field(..., description="The status of the task")]
    target: Annotated[str, Field(..., description="The target of the task")]
    progress: Annotated[list[int], Field(..., description="The progress of the task")]
    restore_point: Annotated[
        int, Field(..., description="The restore point of the task")
    ]
    recovered_hashes: Annotated[
        list[int], Field(..., description="The number of recovered hashes")
    ]
    recovered_salts: Annotated[
        list[int], Field(..., description="The number of recovered salts")
    ]
    rejected: Annotated[int, Field(..., description="The number of rejected guesses")]
    device_statuses: Annotated[
        list[DeviceStatus],
        Field(..., description="The status of the devices used for the task"),
    ]
    time_start: Annotated[
        datetime, Field(..., description="The time the task started.")
    ]
    estimated_stop: Annotated[
        datetime, Field(..., description="The estimated time of completion.")
    ]
    model_config = ConfigDict(extra="forbid")
