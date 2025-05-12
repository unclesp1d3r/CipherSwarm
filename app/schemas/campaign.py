from datetime import datetime

from pydantic import BaseModel, Field


class CampaignRead(BaseModel):
    id: int
    name: str
    description: str | None = None
    created_at: datetime
    updated_at: datetime
    project_id: int
    priority: int = 0
    hash_list_id: int


class CampaignCreate(BaseModel):
    name: str = Field(..., max_length=128)
    description: str | None = Field(None, max_length=512)
    project_id: int
    priority: int = 0
    hash_list_id: int


class CampaignUpdate(BaseModel):
    name: str | None = Field(None, max_length=128)
    description: str | None = Field(None, max_length=512)
    priority: int | None = None


class CampaignProgress(BaseModel):
    active_agents: int = Field(
        ..., description="Number of active agents assigned to this campaign"
    )
    total_tasks: int = Field(..., description="Total number of tasks for this campaign")


class ReorderAttacksRequest(BaseModel):
    attack_ids: list[int] = Field(
        ..., description="List of attack IDs in the desired order"
    )
