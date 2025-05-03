from datetime import datetime

from pydantic import BaseModel

from app.models.task import TaskStatus


class TaskBase(BaseModel):
    state: TaskStatus = TaskStatus.PENDING
    stale: bool = False
    start_date: datetime
    end_date: datetime | None = None
    completed_at: datetime | None = None
    progress_percent: float = 0.0
    progress_keyspace: int = 0
    result_json: dict | None = None
    agent_id: int | None = None
    attack_id: int


class TaskCreate(TaskBase):
    pass


class TaskUpdate(BaseModel):
    state: TaskStatus | None = None
    stale: bool | None = None
    start_date: datetime | None = None
    end_date: datetime | None = None
    completed_at: datetime | None = None
    progress_percent: float | None = None
    progress_keyspace: int | None = None
    result_json: dict | None = None
    agent_id: int | None = None
    attack_id: int | None = None


class TaskOut(TaskBase):
    id: int

    class Config:
        from_attributes = True
