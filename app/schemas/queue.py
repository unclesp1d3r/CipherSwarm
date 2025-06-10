"""Queue monitoring schemas."""

from enum import Enum
from typing import Annotated

from pydantic import BaseModel, Field


class QueueType(str, Enum):
    """Type of queue."""

    asyncio = "asyncio"
    celery = "celery"
    rabbitmq = "rabbitmq"
    redis = "redis"


class QueueHealth(str, Enum):
    """Health of a queue."""

    healthy = "healthy"
    degraded = "degraded"
    unhealthy = "unhealthy"


class StatusEnum(str, Enum):
    """Status of a queue."""

    active = "active"
    idle = "idle"
    inactive = "inactive"


class TaskTypeStats(BaseModel):
    """Statistics for a specific task type."""

    total: Annotated[int, Field(description="Total number of tasks", ge=0)] = 0
    pending: Annotated[int, Field(description="Number of pending tasks", ge=0)] = 0
    running: Annotated[int, Field(description="Number of running tasks", ge=0)] = 0
    failed: Annotated[int, Field(description="Number of failed tasks", ge=0)] = 0


class RecentActivityStats(BaseModel):
    """Recent activity statistics."""

    tasks_last_hour: Annotated[
        int, Field(description="Tasks created in the last hour", ge=0)
    ] = 0


class BackgroundTaskStats(BaseModel):
    """Background task statistics."""

    cracking_tasks: Annotated[
        TaskTypeStats, Field(description="Cracking task statistics")
    ]
    upload_tasks: Annotated[TaskTypeStats, Field(description="Upload task statistics")]
    recent_activity: Annotated[
        RecentActivityStats, Field(description="Recent activity metrics")
    ]


class QueueStatus(BaseModel):
    """Status information for a single queue."""

    name: Annotated[str, Field(description="Queue name")]
    type: Annotated[QueueType, Field(description="Queue type")] = QueueType.asyncio
    pending_jobs: Annotated[int, Field(description="Number of pending jobs", ge=0)] = 0
    running_jobs: Annotated[int, Field(description="Number of running jobs", ge=0)] = 0
    failed_jobs: Annotated[int, Field(description="Number of failed jobs", ge=0)] = 0
    status: Annotated[StatusEnum, Field(description="Queue status")] = StatusEnum.active


class QueueStatusResponse(BaseModel):
    """Comprehensive queue status response."""

    overall_status: Annotated[
        QueueHealth, Field(description="Overall queue system health")
    ] = QueueHealth.healthy
    redis_available: Annotated[
        bool, Field(description="Whether Redis is available")
    ] = True
    redis_memory_usage: Annotated[
        int | None, Field(None, description="Redis memory usage in bytes")
    ] = None
    redis_connections: Annotated[
        int | None, Field(None, description="Number of active Redis connections")
    ] = None
    queues: Annotated[
        list[QueueStatus], Field(description="Individual queue statuses")
    ] = []
    total_pending_jobs: Annotated[
        int, Field(description="Total pending jobs across all queues", ge=0)
    ] = 0
    total_running_jobs: Annotated[
        int, Field(description="Total running jobs across all queues", ge=0)
    ] = 0
    recent_activity: Annotated[
        RecentActivityStats, Field(description="Recent activity metrics")
    ] = RecentActivityStats()
