from pydantic import BaseModel, Field


class MinioHealth(BaseModel):
    status: str = Field(
        ..., description="MinIO service status: healthy, degraded, unreachable"
    )
    latency: float | None = Field(None, description="API response time in seconds")
    error: str | None = Field(None, description="Error message if any")
    bucket_count: int | None = Field(None, description="Number of buckets")


class RedisHealth(BaseModel):
    status: str = Field(
        ..., description="Redis service status: healthy, degraded, unreachable"
    )
    latency: float | None = Field(None, description="Command roundtrip time in seconds")
    error: str | None = Field(None, description="Error message if any")
    memory_usage: int | None = Field(None, description="Memory usage in bytes")
    active_connections: int | None = Field(
        None, description="Number of active connections"
    )


class PostgresHealth(BaseModel):
    status: str = Field(
        ..., description="PostgreSQL service status: healthy, degraded, unreachable"
    )
    latency: float | None = Field(None, description="Query roundtrip time in seconds")
    error: str | None = Field(None, description="Error message if any")


class AgentHealthSummary(BaseModel):
    total_agents: int = Field(..., description="Total number of agents")
    online_agents: int = Field(
        ..., description="Number of agents online (last seen <2min)"
    )
    total_campaigns: int = Field(..., description="Total number of campaigns")
    total_tasks: int = Field(..., description="Total number of tasks")
    total_hashlists: int = Field(..., description="Total number of hash lists")


class SystemHealthOverview(BaseModel):
    minio: MinioHealth
    redis: RedisHealth
    postgres: PostgresHealth
    agents: AgentHealthSummary
