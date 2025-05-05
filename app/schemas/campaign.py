from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class CampaignRead(BaseModel):
    id: UUID
    name: str
    description: str | None = None
    created_at: datetime
    updated_at: datetime
    project_id: UUID


class CampaignCreate(BaseModel):
    name: str = Field(..., max_length=128)
    description: str | None = Field(None, max_length=512)
    project_id: UUID


class CampaignUpdate(BaseModel):
    name: str | None = Field(None, max_length=128)
    description: str | None = Field(None, max_length=512)


class CampaignProgress(BaseModel):
    active_agents: int = Field(
        ..., description="Number of active agents assigned to this campaign"
    )
    total_tasks: int = Field(..., description="Total number of tasks for this campaign")
